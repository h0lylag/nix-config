{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/tailscale.nix
  ];

  networking.hostName = "beavercreek";
  networking.hostId = "8425e349"; # Required for ZFS

  # ZFS configuration is handled by hardware-configuration.nix and disko.nix
  boot.zfs.devNodes = "/dev/disk/by-id";
  services.zfs.autoScrub.enable = true;

  # UEFI bootloader configuration
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;

  # Enable SSH for remote access
  services.openssh.enable = true;
  security.sudo.enable = true;

  system.stateVersion = "25.05";
}
