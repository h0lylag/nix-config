{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  ...
}:

{
  containers.tombstone = {
    autoStart = true;
    enableTun = true;
    privateNetwork = true;
    hostBridge = "br0";

    config =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        imports = [ ../container-base.nix ];
        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        # Adguard Home gets nameservers set with lib.mkForce to prevent it from being set by the container-base config
        networking.nameservers = lib.mkForce [
          "9.9.9.9"
          "149.112.112.112"
        ];

        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.8";
            prefixLength = 24;
          }
        ];

        # Disable resolved - AGH is the DNS server, resolved would conflict on port 53
        services.resolved.enable = false;

        # openFirewall only opens the web UI port, not DNS - add explicitly
        networking.firewall.allowedTCPPorts = [
          53
          3000
        ];
        networking.firewall.allowedUDPPorts = [ 53 ];

        services.adguardhome = {
          enable = true;
          host = "0.0.0.0";
          port = 3000;
          mutableSettings = false; # Prevent AGH web UI from overwriting our nix config

          settings = {
            schema_version = 32;
            dns = {
              upstream_dns = [
                "tls://9.9.9.9"
                "tls://149.112.112.112"
              ];
              bootstrap_dns = [
                "9.9.9.9"
                "149.112.112.112"
              ];
            };
            filtering = {
              protection_enabled = true;
              filtering_enabled = true;
              parental_enabled = false;
              safe_search.enabled = false;
            };
            filters =
              map
                (url: {
                  enabled = true;
                  url = url;
                })
                [
                  "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"
                  "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt"
                ];
          };
        };
      };
  };
}
