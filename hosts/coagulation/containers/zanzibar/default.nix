# Zanzibar Container configuration for coagulation
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Enable container support
  boot.enableContainers = true;

  # Define zanzibar container
  containers.zanzibar = {
    autoStart = true; # Set to autostart

    # Bridge networking - container gets its own MAC and DHCP lease
    privateNetwork = true;
    hostBridge = "br0";

    # Container configuration
    config =
      { config, pkgs, ... }:
      {
        # Import qbittorrent service
        imports = [
          ./qbittorrent.nix
          ./sonarr.nix
          ./qui.nix
        ];

        # Basic system settings
        system.stateVersion = "25.05";

        # Timezone and locale (from base profile)
        time.timeZone = "America/Los_Angeles";
        i18n.defaultLocale = "en_US.UTF-8";

        # Basic packages
        environment.systemPackages = with pkgs; [
          htop
          nano
          wget
          curl
        ];

        # Container will get IP via DHCP
        networking.interfaces.eth0.useDHCP = true;
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
        users.users.chris = {
          isNormalUser = true;
          extraGroups = [
            "networkmanager"
            "wheel"
          ];
          initialPassword = "chris"; # Must be changed on first login
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWU3a+HOcu4woQiuMoCSxrW8g916Z9P05DW8o7cGysH chris@relic"
          ];
        };

        # Firewall
        networking.firewall.enable = true;
        networking.firewall.allowedTCPPorts = [
          22
        ];
        networking.firewall.allowedUDPPorts = [ ];
      };
  };
}
