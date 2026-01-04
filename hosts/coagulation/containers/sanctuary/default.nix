# Sanctuary - Jellyfin container
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  ...
}:

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
      {
        imports = [
          ../container-base.nix
        ];

        _module.args.nixpkgs-unstable = nixpkgs-unstable;

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
          package = pkgs.unstable.jellyfin;
          user = "jellyfin";
          group = "media";
          openFirewall = true;
        };

        # Jellyseerr Service
        services.jellyseerr = {
          enable = true;
          package = pkgs.unstable.jellyseerr;
          openFirewall = true;
        };

        systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";
      };
  };
}
