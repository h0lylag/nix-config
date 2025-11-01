# midship - Hetzner-cloud VM (OVH datacenter)
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
    ../../modules/sftp-chroot.nix
    ./services/sftp-chroot.nix
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking = {
    hostName = "midship";
    networkmanager.enable = true;
    enableIPv6 = false;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
      ];
      allowedUDPPorts = [ ];
    };
  };

  services.openssh.enable = true;

  # Automatic system updates at 3:30 AM
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "03:30";
  };

  system.stateVersion = "23.11";
}
