# containment - Hetzner-cloud VM (OVH datacenter)
{ pkgs, lib, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../profiles/common.nix
    ./web/ssl.nix
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
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };
  };

  # Cloudflare API credentials for ACME DNS-01 validation
  sops.secrets.cloudflare = {
    sopsFile = ../../secrets/cloudflare.env;
    format = "dotenv";
    mode = "0440";
    owner = "root";
    group = "acme";
    path = "/run/secrets/cloudflare";
  };

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
