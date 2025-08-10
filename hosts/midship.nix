{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../hardware/midship.nix
    ../modules/common.nix
    ../modules/tailscale.nix
  ];

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # Networking
  networking.hostName = "midship";
  networking.networkmanager.enable = true;
  networking.enableIPv6 = false;

  # Enable Services
  services.openssh.enable = true;

  # Firewall Rules
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [ ];

  # Automatic System Updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "03:30";
  };

  system.stateVersion = "23.11";
}
