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

  # ZFS configuration
  boot.zfs.devNodes = "/dev/disk/by-id";
  services.zfs.autoScrub.enable = true;

  # UEFI bootloader configuration
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;

  # Networking configuration
  networking.hostName = "beavercreek";
  networking.hostId = "8425e349"; # Required for ZFS
  networking.enableIPv6 = false;
  networking.defaultGateway = "10.1.1.1";
  networking.interfaces.ens18.ipv4.addresses = [
    {
      address = "10.1.1.50";
      prefixLength = 24;
    }
  ];

  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
    "10.1.1.1"
  ];

  # Enable SSH for remote access
  services.openssh.enable = true;

  # Firewall Rules
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
  ];
  networking.firewall.allowedUDPPorts = [ ];

  system.stateVersion = "25.05";
}
