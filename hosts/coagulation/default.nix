# coagulation - Home server public facing machine
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = false;
  };

  networking = {
    hostName = "coagulation";
    networkmanager.enable = true;
    enableIPv6 = false;
    defaultGateway = "10.1.1.1";

    interfaces.ens18.ipv4.addresses = [
      {
        address = "10.1.1.10";
        prefixLength = 24;
      }
    ];

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
      "10.1.1.1"
    ];

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

  system.stateVersion = "24.05";
}
