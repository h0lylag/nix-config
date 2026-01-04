# Zanzibar - systemd-nspawn container configuration on coagulation host
{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  ...
}:

let
  unstable = import nixpkgs-unstable {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in

{
  # Enable container support
  boot.enableContainers = true;

  # Define zanzibar container
  containers.zanzibar = {
    autoStart = true; # Set to autostart

    # Bridge networking - container gets its own MAC and DHCP lease
    privateNetwork = true;
    hostBridge = "br0";

    # Bind mounts
    bindMounts = {
      "/mnt/hdd-pool/main" = {
        hostPath = "/mnt/hdd-pool/main";
        isReadOnly = false;
      };
      "/mnt/nvme-pool/scratch" = {
        hostPath = "/mnt/nvme-pool/scratch";
        isReadOnly = false;
      };
    };

    # Container configuration
    config =
      { config, pkgs, ... }:

      {
        # unstable nixpkgs overlay
        nixpkgs.overlays = [
          (final: prev: {
            unstable = unstable;
          })
        ];

        # Import qbittorrent service
        imports = [
          ./services/qbittorrent.nix
          ./services/sonarr.nix
          ./services/qui.nix
          ./services/jellyfin.nix
        ];

        # Timezone and locale (from base profile)
        time.timeZone = "America/Los_Angeles";
        i18n.defaultLocale = "en_US.UTF-8";

        # Container static IP configuration
        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.11";
            prefixLength = 24;
          }
        ];
        networking.defaultGateway = "10.1.1.1";
        networking.useHostResolvConf = lib.mkForce false;
        networking.nameservers = [
          "10.1.1.1"
          "1.1.1.1"
          "8.8.8.8"
        ];

        # Enable SSH
        services.openssh = {
          enable = true;
          settings.PermitRootLogin = "prohibit-password";
          settings.PasswordAuthentication = true;
        };

        # User configuration
        users.groups.media = {
          gid = 1300;
        };

        users.users.chris = {
          isNormalUser = true;
          extraGroups = [
            "networkmanager"
            "wheel"
            "media"
          ];
          initialPassword = "chris"; # Must be changed on first login
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWU3a+HOcu4woQiuMoCSxrW8g916Z9P05DW8o7cGysH chris@relic"
          ];
        };

        # Explicitly add service users to media group
        users.users.sonarr.extraGroups = [ "media" ];
        users.users.jellyfin.extraGroups = [ "media" ];
        users.users.qbittorrent.extraGroups = [ "media" ];
        users.users.qui.extraGroups = [ "media" ];

        # Basic packages
        environment.systemPackages = with pkgs; [
          htop
          nano
          wget
          curl
        ];

        # Firewall
        networking.firewall.enable = true;
        networking.firewall.allowedTCPPorts = [
          22
        ];
        networking.firewall.allowedUDPPorts = [ ];

        system.stateVersion = "25.11";
      };
  };
}
