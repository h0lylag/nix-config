# containment - Hetzner-cloud VM (OVH datacenter)
{ pkgs, lib, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../profiles/base.nix
  ];

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 4 * 1024;
    }
  ];

  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 50;
    priority = 100;
  };

  networking = {
    hostName = "containment";
    useDHCP = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
      ];
      allowedUDPPorts = [ ];
    };
  };

  services.openssh.enable = true;

  system.stateVersion = "25.11";
}
