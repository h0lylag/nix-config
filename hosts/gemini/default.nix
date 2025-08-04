{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../hardware/gemini.nix
    ../../modules/common.nix
    ../../modules/tailscale.nix
    ./web/php.nix
    ./web/nginx.nix
    ./web/ssl.nix
    ./services/discord-relay.nix
    ./services/overseer.nix
    ./services/diamond-boys.nix
    ./services/minecraft.nix
  ];

  # EFI Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "gemini";
  networking.useDHCP = false;
  networking.enableIPv6 = false;

  networking.defaultGateway = "147.135.105.254";
  networking.interfaces.enp1s0f0.ipv4.addresses = [
    {
      address = "147.135.105.6";
      prefixLength = 24;
    }
  ];

  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # Users
  users.users = {
    nginx = {
      isSystemUser = true;
      group = "nginx";
      extraGroups = [ "log" ];
    };

    dayz = {
      isNormalUser = true;
    };

    minecraft = {
      isNormalUser = true;
    };
  };

  # SSH
  services.openssh.enable = true;
  networking.firewall.enable = false;

  networking.firewall = {
    allowedTCPPorts = [
      22
      80
      443
      2304
      2304
      2305
      2306
      25565
      25566
    ];
    allowedUDPPorts = [
      41641
      2302
      2304
      2305
      2306
      24454
    ];
    trustedInterfaces = [ "tailscale0" ];
  };

  environment.systemPackages = with pkgs; [
    python3
    python311Packages.pip
    python311Packages.virtualenv
    temurin-bin-21
    steamcmd
    steam-run
  ];

  # Enable LD, to allow use of dynamically linked binaries
  programs.nix-ld.enable = true;

  # MySQL stuff
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    package = pkgs.postgresql_16;
    dataDir = "/var/lib/postgresql/16";
  };

  system.stateVersion = "24.11";
}
