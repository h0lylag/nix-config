# Sanctuary - Jellyfin container
{
  config,
  pkgs,
  lib,
  ...
}:

let
  tunarr = pkgs.callPackage ../../../../pkgs/tunarr/package.nix { };
in
{
  containers.sanctuary = {
    autoStart = true;
    enableTun = true;
    privateNetwork = true;
    hostBridge = "br0";

    bindMounts = {
      "/mnt/hdd-pool/main" = {
        hostPath = "/mnt/hdd-pool/main";
        isReadOnly = false;
      };
      "/mnt/nvme-pool/scratch" = {
        hostPath = "/mnt/nvme-pool/scratch";
        isReadOnly = false;
      };
    };

    config =
      { config, pkgs, ... }:
      let
        jellyfinXmltv = pkgs.unstable.callPackage ../../../../pkgs/jellyfin-xmltv/package.nix { };
        # Jellyfin 12.1 skips programme icons immediately following <image> in
        # Tunarr's compact XMLTV. Re-audit this replacement on server upgrades.
        jellyfin =
          assert lib.assertMsg (
            pkgs.unstable.jellyfin.version == "12.1"
          ) "Re-audit Sanctuary's XMLTV parser patch for this Jellyfin version.";
          pkgs.unstable.jellyfin.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              install -m644 ${jellyfinXmltv}/lib/jellyfin-xmltv/Jellyfin.XmlTv.dll \
                "$out/lib/jellyfin/Jellyfin.XmlTv.dll"
            '';
            passthru = (old.passthru or { }) // {
              xmltvParser = jellyfinXmltv;
            };
          });
      in
      {
        imports = [
        ];

        # Network Configuration
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.11";
            prefixLength = 24;
          }
        ];

        # Explicitly add service user to media group (defined in base)
        users.users.jellyfin.extraGroups = [ "media" ];

        # Jellyfin Service
        services.jellyfin = {
          enable = true;
          package = jellyfin;
          user = "jellyfin";
          group = "media";
          openFirewall = true;
        };

        # Seerr Service
        services.seerr = {
          enable = true;
          package = pkgs.unstable.seerr;
          openFirewall = true;
        };

        # The upstream standalone binary expects an FHS loader and stores
        # absolute FFmpeg paths in its writable settings.
        programs.nix-ld.enable = true;

        users.users.tunarr = {
          isSystemUser = true;
          group = "media";
          home = "/var/lib/tunarr";
        };

        systemd.services.tunarr = {
          description = "Tunarr virtual TV server";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];

          environment = {
            HOME = "/var/lib/tunarr";
            TUNARR_DATABASE_PATH = "/var/lib/tunarr";
            TUNARR_SERVER_PORT = "8000";
          };

          serviceConfig = {
            User = "tunarr";
            Group = "media";
            StateDirectory = "tunarr";
            WorkingDirectory = "/var/lib/tunarr";
            BindReadOnlyPaths = [
              "${pkgs.ffmpeg_7-full}/bin/ffmpeg:/usr/bin/ffmpeg"
              "${pkgs.ffmpeg_7-full}/bin/ffprobe:/usr/bin/ffprobe"
            ];
            ExecStart = "${tunarr}/bin/tunarr";
            Restart = "on-failure";
            RestartSec = "10s";
            UMask = "0002";

            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
          };
        };

        networking.firewall.allowedTCPPorts = [ 8000 ];

        systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";
      };
  };
}
