# midship - Hetzner-cloud VM (OVH datacenter)
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
    ../../modules/sftp-chroot.nix
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

  services.sftpChroot = {
    enable = true;

    # Only non-default settings below:
    requireAuth = false; # Allow setting password after deployment with: sudo passwd sven

    users.sven = {
      # Password will be set manually after deployment
      # Alternatively, set passwordHash or authorizedKeys here
    };
  };

  # Automatic system updates at 3:30 AM
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "03:30";
  };

  system.stateVersion = "23.11";
}
