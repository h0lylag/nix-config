{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ../hardware/coagulation.nix
    ../modules/common.nix
    ../modules/tailscale.nix
  ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = false;

  networking.hostName = "coagulation";
  networking.networkmanager.enable = true;
  networking.enableIPv6 = false;

  networking.defaultGateway = "10.1.1.1";
  networking.interfaces.ens18.ipv4.addresses = [
    {
      address = "10.1.1.10";
      prefixLength = 24;
    }
  ];

  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
    "10.1.1.1"
  ];

  # Installed Packages
  environment.systemPackages = with pkgs; [
    fail2ban
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    22
    80
    443
  ];

  system.stateVersion = "24.05";

}
