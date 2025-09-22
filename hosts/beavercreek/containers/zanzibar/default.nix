# Zanzibar Container configuration for beavercreek
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
        # Import common configuration and services
        imports = [
          ../../../../modules/common.nix
          ./qbittorrent.nix
        ];
        # Basic system settings
        system.stateVersion = "25.05";

        # Container will get IP via DHCP
        networking.interfaces.eth0.useDHCP = true;
        networking.useHostResolvConf = lib.mkForce false;
        networking.nameservers = [
          "10.1.1.1"
          "1.1.1.1"
          "8.8.8.8"
        ];

        # Enable SSH (common.nix configures SSH settings)
        services.openssh.enable = true;

        # Set initial password for chris user (common.nix defines the user)
        users.users.chris.initialPassword = "chris"; # Must be changed on first login

        # Basic packages are provided by common.nix
        # Sudo is configured in common.nix

        # Open some ports for testing
        networking.firewall.allowedTCPPorts = [
          22
        ];
        networking.firewall.allowedUDPPorts = [ ];
      };
  };
}
