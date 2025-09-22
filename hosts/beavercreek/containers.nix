# NixOS Containers configuration for beavercreek
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Enable container support
  boot.enableContainers = true;

  # Use systemd-networkd for host networking (avoid dhcpcd conflicts)
  networking.useNetworkd = true;
  networking.useDHCP = false;

  # Create a bridge interface for container networking
  networking.bridges = {
    br0 = {
      interfaces = [ "ens18" ]; # Attach physical interface to bridge
    };
  };

  # Network gateway and DNS configuration
  networking.defaultGateway = {
    address = "10.1.1.1";
    interface = "br0";
  };
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
    "10.1.1.1"
  ];

  # Configure the host to use the bridge instead of direct interface
  networking.interfaces = {
    # Disable DHCP on the physical interface since bridge will handle it
    ens18.useDHCP = false;

    # Configure the bridge with static IP
    br0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.1.1.50";
          prefixLength = 24;
        }
      ];
    };
  };

  # Define containers
  containers.test-container = {
    # Enable the container
    autoStart = true;

    # Bridge networking - container gets its own MAC and DHCP lease
    privateNetwork = true;
    interfaces = [ "veth-test" ]; # Virtual ethernet interface name

    # Container configuration
    config =
      { config, pkgs, ... }:
      {
        # Basic system settings
        system.stateVersion = "25.05";

        # Container will get IP via DHCP from your router
        networking.interfaces.eth0.useDHCP = true;
        networking.useHostResolvConf = lib.mkForce false;
        networking.nameservers = [
          "10.1.1.1" # Your router
          "1.1.1.1"
          "8.8.8.8"
        ];

        # Install some basic packages
        environment.systemPackages = with pkgs; [
          curl
          wget
          htop
          nano
          iproute2
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
          80
          8080
        ];
      };
  };

  # Attach container interface to bridge
  systemd.network = {
    enable = true;
    networks."50-veth-test" = {
      matchConfig.Name = "veth-test";
      networkConfig = {
        Bridge = "br0";
      };
    };
  };
}
