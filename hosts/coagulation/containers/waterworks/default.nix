# Waterworks - Sonarr container
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  ...
}:

{
  containers.waterworks = {
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
      {
        imports = [
          ../base.nix
        ];

        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        # Network Configuration
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.13";
            prefixLength = 24;
          }
        ];

        # Explicitly add service user to media group (defined in base)
        users.users.sonarr.extraGroups = [ "media" ];
        users.users.radarr.extraGroups = [ "media" ];

        users.users.prowlarr = {
          isSystemUser = true;
          group = "prowlarr";
          extraGroups = [ "media" ];
        };
        users.groups.prowlarr = { };

        # Sonarr Service
        services.sonarr = {
          enable = true;
          package = pkgs.unstable.sonarr;
          user = "sonarr";
          group = "media";
          openFirewall = true;
        };

        systemd.services.sonarr.serviceConfig.UMask = "0002";

        # Radarr Service
        services.radarr = {
          enable = true;
          package = pkgs.unstable.radarr;
          user = "radarr";
          group = "media";
          openFirewall = true;
        };

        systemd.services.radarr.serviceConfig.UMask = "0002";

        # Prowlarr Service
        services.prowlarr = {
          enable = true;
          package = pkgs.unstable.prowlarr;
          openFirewall = true;
        };

        systemd.services.prowlarr.serviceConfig.UMask = "0002";
      };
  };
}
