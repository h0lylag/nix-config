# midship - Hetzner-cloud VM (OVH datacenter)
{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
    ./web/php.nix
    ./web/ssl.nix
    ./web/nginx.nix
    ./services/discord-relay.nix
    ./services/diamond-boys.nix
    ./services/workshop-watcher.nix
    ./services/minecraft.nix
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
        5432 # PostgreSQL
      ];
      allowedUDPPorts = [ ];
    };
  };

  # Additional users for gemini (chris comes from base.nix)
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
    extraGroups = [ "log" ];
  };

  services = {
    mysql = {
      enable = true;
      package = pkgs.mariadb;
    };

    postgresql = {
      enable = true;
      enableTCPIP = true;
      package = pkgs.postgresql_16;
      dataDir = "/var/lib/postgresql/16";
      authentication = pkgs.lib.mkOverride 10 ''
        # Allow remote connections from specific hosts
        host    all   all   100.121.88.122         scram-sha-256
        host    all   all   lockout       scram-sha-256
        host    all   all   coagulation   scram-sha-256
      '';
    };

    sftpChroot = {
      enable = true;
      requireAuth = false; # allow password configuration post-deploy
      fixChrootPerms = true;
      users.sven = { };
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

  services.openssh.enable = true;

  # Automatic system updates at 3:30 AM
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "03:30";
  };

  system.stateVersion = "23.11";
}
