# backwash - HP ZBook Firefly 14 G11 A
{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../profiles/common.nix
    ../../profiles/workstation.nix
    ../../profiles/gaming.nix
    ../../features/nixcord.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "backwash";

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
  };

  systemd.oomd.enable = true;

  hardware.bluetooth.enable = true;

  # Keep the builder definition ready, but do not use distributed builds for now.
  nix.distributedBuilds = false;
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

  environment.systemPackages = with pkgs; [
    rustdesk-flutter
  ];

  system.stateVersion = "26.05";
}
