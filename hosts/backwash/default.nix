# backwash - Thinkpad x230 laptop
{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../profiles/common.nix
    ../../profiles/workstation.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "backwash";

  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

  # Enable distributed builds to speed up rebuilds on this older laptop
  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "coagulation";
      system = "x86_64-linux";
      protocol = "ssh-ng";
      maxJobs = 16;
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
  nix.settings.builders-use-substitutes = true;

  system.stateVersion = "25.11";
}
