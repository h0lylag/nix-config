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

          # Database client libraries (not server binaries)
          mariadb-client

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

        # Alliance Auth systemd services
        systemd.services.allianceauth-gunicorn = {
          description = "Alliance Auth Gunicorn Web Server";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network.target"
            "mysql.service"
            "redis.service"
          ];
          serviceConfig = {
            Type = "simple";
            User = "allianceserver";
            Group = "allianceserver";
            WorkingDirectory = "/home/allianceserver/myauth";
            ExecStart = "/home/allianceserver/venv/auth/bin/gunicorn --bind 127.0.0.1:8000 --workers 3 --timeout 120 myauth.wsgi";
            Restart = "always";
            RestartSec = 10;
            Environment = [
              "DJANGO_SETTINGS_MODULE=myauth.settings.local"
            ];
          };
        };

        systemd.services.allianceauth-celery-worker = {
          description = "Alliance Auth Celery Worker";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network.target"
            "mysql.service"
            "redis.service"
          ];
          serviceConfig = {
            Type = "simple";
            User = "allianceserver";
            Group = "allianceserver";
            WorkingDirectory = "/home/allianceserver/myauth";
            ExecStart = "/home/allianceserver/venv/auth/bin/celery -A myauth worker --loglevel=info --concurrency=2";
            Restart = "always";
            RestartSec = 10;
            Environment = [
              "DJANGO_SETTINGS_MODULE=myauth.settings.local"
            ];
          };
        };

        systemd.services.allianceauth-celery-beat = {
          description = "Alliance Auth Celery Beat Scheduler";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network.target"
            "mysql.service"
            "redis.service"
          ];
          serviceConfig = {
            Type = "simple";
            User = "allianceserver";
            Group = "allianceserver";
            WorkingDirectory = "/home/allianceserver/myauth";
            ExecStart = "/home/allianceserver/venv/auth/bin/celery -A myauth beat --loglevel=info";
            Restart = "always";
            RestartSec = 10;
            Environment = [
              "DJANGO_SETTINGS_MODULE=myauth.settings.local"
            ];
          };
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
