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
    ../../modules/satisfactory.nix
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
  networking.firewall.enable = true;

  networking.firewall = {
    allowedTCPPorts = [
      22 # SSH
      80 # HTTP
      443 # HTTPS
      2304 # DayZ
      2305 # DayZ
      2306 # DayZ
      25565 # Minecraft
      25566 # Minecraft
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
    steamcmd
    steam-run
  ];

  # Enable LD, to allow use of dynamically linked binaries
  programs.nix-ld.enable = true;

  # enable satisfactory dedicated server
  services.satisfactory = {
    enable = true;
    extraArgs = "-multihome=147.135.105.6";
  };

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
