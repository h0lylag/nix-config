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
          ../container-base.nix
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

        # Sonarr Service
        services.sonarr = {
          enable = true;
          package = pkgs.unstable.sonarr;
          user = "sonarr";
          group = "media";
          openFirewall = true;
        };

        systemd.services.sonarr.serviceConfig.UMask = "0002";
      };
  };
}
