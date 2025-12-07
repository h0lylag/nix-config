# midship - Hetzner-cloud VM (OVH datacenter)
{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
    ../../modules/sftp-chroot.nix
    ./web/php.nix
    ./web/ssl.nix
    ./web/nginx.nix
    ./services/discord-relay.nix
    #./services/diamond-boys.nix
    #./services/workshop-watcher.nix
    ./services/minecraft.nix
    ./services/postgresql.nix
    ./services/redis.nix
    ./services/prism-django.nix
    ./services/overseer.nix
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  # Enable zswap for compressed swap in RAM
  boot.kernelParams = [
    "zswap.enabled=1"
    "zswap.compressor=zstd"
    "zswap.zpool=z3fold"
    "zswap.max_pool_percent=20"
    "zswap.shrinker_enabled=1"
  ];
  boot.kernel.sysctl = {
    "vm.swappiness" = 80;
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

  # use our SFTP Chroot module to set up sven with access
  # jail path: /srv/www/sven
  services.sftpChroot = {
    enable = true;
    users.sven = { };
    passwordAuth = true;
  };

  # Additional users for gemini (chris comes from base.nix)
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
    extraGroups = [ "log" ];
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
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

  services.openssh.enable = true;

  # Automatic system updates at 3:30 AM
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "03:30";
  };

  system.stateVersion = "23.11";
}
