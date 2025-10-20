# gemini - OVH dedicated server
# Game servers, web hosting, databases
{ pkgs, ... }:

let
  dayz-tools = pkgs.callPackage ../../pkgs/dayz-tools/default.nix { };
in

{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../features/tailscale.nix
    ../../modules/satisfactory.nix
    ../../modules/dayz-server.nix
    ./web/php.nix
    ./web/nginx.nix
    ./web/ssl.nix
    ./services/discord-relay.nix
    ./services/overseer.nix
    ./services/diamond-boys.nix
    ./services/minecraft.nix
    ./services/workshop-watcher.nix
    ./services/dayz-server.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "gemini";
    useDHCP = false;
    enableIPv6 = false;
    defaultGateway = "147.135.105.254";
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];

    interfaces.enp1s0f0.ipv4.addresses = [
      {
        address = "147.135.105.6";
        prefixLength = 24;
      }
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

  users.users = {
    nginx = {
      isSystemUser = true;
      group = "nginx";
      extraGroups = [ "log" ];
    };

    dayz = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWU3a+HOcu4woQiuMoCSxrW8g916Z9P05DW8o7cGysH chris@relic"
      ];
    };
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    extraConfig = ''
      Match User dayz,minecraft
        PasswordAuthentication no
      Match all
    '';
  };

  environment.systemPackages = with pkgs; [
    python3
    python311Packages.pip
    python311Packages.virtualenv
    steamcmd
    steam-run
    dayz-tools.a2s-info
    dayz-tools.xml-validator
  ];

  services = {
    satisfactory = {
      enable = false;
      extraArgs = "-multihome=147.135.105.6";
    };

    mysql = {
      enable = true;
      package = pkgs.mariadb;
    };

    postgresql = {
      enable = true;
      enableTCPIP = true;
      package = pkgs.postgresql_16;
      dataDir = "/var/lib/postgresql/16";
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

  system.stateVersion = "24.11";
}
