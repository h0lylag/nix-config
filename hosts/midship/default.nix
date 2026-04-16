# midship - Hetzner-cloud VM (OVH datacenter)
{ pkgs, lib, ... }:

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../profiles/common.nix
    ../../modules/sftp-chroot.nix
    ./web/ssl.nix
    ./web/php.nix
    ./web/nginx.nix
    ./services/discord-relay.nix
    ./services/postgresql.nix
    ./services/redis.nix
    ./services/prism-django.nix
    ./services/overseer.nix
  ];

  services.sftpChroot = {
    enable = false;
    users.sven = { };
    passwordAuth = true;
  };

  services.openssh.enable = true;

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 4 * 1024;
    }
  ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
  };

  systemd.oomd.enable = true;

  networking = {
    hostName = "midship";
    useDHCP = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
        25565
      ];
      allowedUDPPorts = [ ];
    };
  };

  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
    extraGroups = [ "log" ];
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
