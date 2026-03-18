# GeoIP country blocking using nftables native sets
# Downloads aggregated CIDR blocks from ipdeny.com and loads them
# into nftables sets, then drops incoming traffic from those ranges.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.geoip-block;
in
{
  options.features.geoip-block = {
    enable = lib.mkEnableOption "GeoIP country blocking";

    countries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "cn"
        "ru"
        "kp"
        "ir"
      ];
      description = "ISO 3166-1 alpha-2 country codes to block (lowercase).";
    };

    blockedPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = ''
        TCP ports to block from listed countries.
        If empty, all incoming traffic from those countries is dropped.
      '';
    };

    refreshInterval = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "systemd OnCalendar expression for how often to refresh the blocklists.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Switch firewall backend to nftables (existing networking.firewall options still work)
    networking.nftables.enable = true;

    # Define a separate table so we don't touch the NixOS-managed firewall
    networking.nftables.tables.geoip-block = {
      family = "inet";
      content = ''
        set geoip_block_v4 {
          type ipv4_addr
          flags interval
          auto-merge
        }

        chain input {
          type filter hook input priority -10; policy accept;
          ${
            if cfg.blockedPorts == [ ] then
              "ip saddr @geoip_block_v4 drop"
            else
              "tcp dport { ${lib.concatMapStringsSep ", " toString cfg.blockedPorts} } ip saddr @geoip_block_v4 drop"
          }
        }
      '';
    };

    # Service to download country CIDR blocks and load into nftables sets
    systemd.services.geoip-blocklist = {
      description = "Load GeoIP blocklists into nftables sets";
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "nftables.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [
        curl
        nftables
      ];
      script =
        let
          countries = lib.concatStringsSep " " cfg.countries;
        in
        ''
          set -euo pipefail

          TMPDIR=$(mktemp -d)
          trap 'rm -rf "$TMPDIR"' EXIT

          for country in ${countries}; do
            echo "Downloading blocklist for $country..."
            if ! curl -sf --retry 3 --max-time 30 \
              "https://www.ipdeny.com/ipblocks/data/aggregated/''${country}-aggregated.zone" \
              -o "$TMPDIR/$country.zone"; then
              echo "Warning: failed to download $country blocklist, skipping"
              continue
            fi
          done

          # Build nftables commands to flush and reload the set
          {
            echo "flush set inet geoip-block geoip_block_v4"
            for country in ${countries}; do
              [ -f "$TMPDIR/$country.zone" ] || continue
              while IFS= read -r cidr; do
                [ -n "$cidr" ] && echo "add element inet geoip-block geoip_block_v4 { $cidr }"
              done < "$TMPDIR/$country.zone"
            done
          } > "$TMPDIR/load.nft"

          echo "Loading $(wc -l < "$TMPDIR/load.nft") nftables commands..."
          nft -f "$TMPDIR/load.nft"
          echo "GeoIP blocklist loaded successfully"
        '';
    };

    # Timer to refresh the blocklists periodically
    systemd.timers.geoip-blocklist = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.refreshInterval;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
