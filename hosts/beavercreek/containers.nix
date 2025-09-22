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

  # Define containers
  containers.test-container = {
    autoStart = true;

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

  # Alliance Auth container
  containers.allianceauth = {
    autoStart = true;

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

        # Install required packages for Alliance Auth
        environment.systemPackages = with pkgs; [
          # Python 3.11 and development tools
          python311
          python311Packages.pip
          python311Packages.setuptools
          python311Packages.wheel
          python311Packages.virtualenv

          # Database and Redis
          mariadb
          redis

          # Build tools and dependencies
          gcc
          gccStdenv
          unzip
          git
          curl
          wget
          pkg-config

          # SSL and crypto libraries
          openssl
          libffi
          bzip2

          # System utilities
          htop
          nano
          vim
          supervisor

          # Web server (nginx for reverse proxy)
          nginx
        ];

        # Enable MariaDB service
        services.mysql = {
          enable = true;
          package = pkgs.mariadb;
          settings = {
            mysqld = {
              character-set-server = "utf8mb4";
              collation-server = "utf8mb4_unicode_ci";
            };
          };
        };

        # Enable Redis service
        services.redis = {
          enable = true;
        };

        # Enable Supervisor for process management
        services.supervisor = {
          enable = true;
        };

        # Enable SSH for remote access
        services.openssh = {
          enable = true;
          settings.PermitRootLogin = "yes";
          settings.PasswordAuthentication = true;
        };

        # Create allianceserver user
        users.users.allianceserver = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          password = "allianceauth123"; # Change this!
          home = "/home/allianceserver";
          createHome = true;
        };

        # Enable sudo
        security.sudo.enable = true;

        # Create directories for Alliance Auth
        systemd.tmpfiles.rules = [
          "d /var/www/myauth/static 0755 allianceserver allianceserver -"
          "d /home/allianceserver/venv 0755 allianceserver allianceserver -"
          "d /home/allianceserver/myauth 0755 allianceserver allianceserver -"
          "d /home/allianceserver/myauth/log 0755 allianceserver allianceserver -"
        ];

        # Open ports for Alliance Auth
        networking.firewall.allowedTCPPorts = [
          22 # SSH
          80 # HTTP
          443 # HTTPS
          8000 # Development server (if needed)
        ];

      };
  };

}
