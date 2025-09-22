# Test Container configuration for beavercreek
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Enable container support
  boot.enableContainers = true;

  # Define test container
  containers.test-container = {
    autoStart = false; # Changed from true to false

    # Bridge networking - container gets its own MAC and DHCP lease
    privateNetwork = true;
    hostBridge = "br0";

    # Container configuration
    config =
      { config, pkgs, ... }:
      {
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

        # Install some basic packages
        environment.systemPackages = with pkgs; [
          curl
          wget
          htop
          nano
        ];

        # Enable SSH for remote access
        services.openssh = {
          enable = true;
          settings.PermitRootLogin = "yes";
          settings.PasswordAuthentication = true;
        };

        # Create a test user
        users.users.test = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          password = "test123"; # Change this!
        };

        # Enable sudo
        security.sudo.enable = true;

        # Open some ports for testing
        networking.firewall.allowedTCPPorts = [
          22
        ];
      };
  };
}
