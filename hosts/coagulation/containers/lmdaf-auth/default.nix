# Alliance Auth Container configuration for coagulation
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Enable container support
  boot.enableContainers = true;

  # Alliance Auth container
  containers.lmdaf-auth = {
    autoStart = true;

    # Bridge networking - container gets its own MAC and DHCP lease
    privateNetwork = true;
    hostBridge = "br0";

    # Container configuration
    config =
      { config, pkgs, ... }:
      {
        # Basic system settings
        system.stateVersion = "25.11";

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
          python313
          python313Packages.pip
          python313Packages.setuptools
          python313Packages.wheel
          python313Packages.virtualenv
          python313Packages.supervisor

          # Database client libraries and development headers
          mariadb.client
          libmysqlclient

          # Build tools and dependencies
          gcc
          unzip
          git
          curl
          wget
          tzdata
          pkg-config

          # SSL and crypto libraries
          openssl
          libffi
          bzip2

          # System utilities
          htop
          nano
          vim
        ];

        # Environment variables for building Python packages with MySQL support
        # libmysqlclient provides the mysql.h header and libraries
        environment.variables = {
          MYSQLCLIENT_CFLAGS = "-I${pkgs.libmysqlclient}/include/mysql";
          MYSQLCLIENT_LDFLAGS = "-L${pkgs.libmysqlclient}/lib";
        };

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
        services.redis.servers."" = {
          enable = true;
        };

        # Enable SSH for remote access
        services.openssh = {
          enable = true;
          settings.PermitRootLogin = "prohibit-password";
        };

        # Create allianceserver user
        users.users.allianceserver = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          home = "/home/allianceserver";
          createHome = true;
          password = "allianceauth";
        };

        # Enable sudo
        security.sudo.enable = true;

        # Create base directories
        systemd.tmpfiles.rules = [
          "d /var/www/myauth/static 0755 allianceserver allianceserver -"
          "d /home/allianceserver/venv 0755 allianceserver allianceserver -"
        ];

        # Open ports
        networking.firewall.allowedTCPPorts = [
          22 # SSH
          80 # HTTP
          443 # HTTPS
          8000 # Gunicorn
        ];
      };
  };
}
