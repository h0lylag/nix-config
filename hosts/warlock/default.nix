# warlock - Oracle Cloud free tier VM
# x86_64, UEFI, single disk
{ pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    #../../profiles/common.nix
  ];

  services.openssh.enable = true;

  networking = {
    hostName = "warlock";
    useDHCP = false;
    interfaces.ens3 = {
      useDHCP = true;
      mtu = 9000;
    };
    firewall.allowedTCPPorts = [ 22 ];
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024;
    }
  ];

  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 50;
    priority = 100;
  };

  #programs.java.enable = lib.mkForce false;
  #programs.nix-ld.enable = lib.mkForce false;

  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "coagulation";
      system = "x86_64-linux";
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 10;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
      sshUser = "root";
      sshKey = "/etc/nix/build-machine-key";
    }
  ];

  system.stateVersion = "25.11";
}
