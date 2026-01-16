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
        imports = [
          ../base.nix
        ];

        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        # Static IP configuration (overrides base)
        networking.interfaces.eth0.useDHCP = false;
        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.14";
            prefixLength = 24;
          }
        ];

        # Alliance Auth Dependencies
        environment.systemPackages = with pkgs; [
          # Python & Supervisor
          python313
          python313Packages.pip
          python313Packages.setuptools
          python313Packages.wheel
          python313Packages.virtualenv
          python313Packages.supervisor

          # Database
          mariadb
          mariadb.client
          libmysqlclient.dev

          # Build Tools
          gcc
          unzip
          git
          tzdata
          pkg-config

          # Crypto
          openssl
          libffi
          bzip2

          # Web Server
          nginx
        ];

        # Environment variables for building Python packages with MySQL support
        # Use pkg-config from libmysqlclient.dev to discover mysql client library
        environment.variables = {
          PKG_CONFIG_PATH = "${pkgs.libmysqlclient.dev}/lib/pkgconfig";
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

        # Enable nginx as reverse proxy
        services.nginx = {
          enable = true;
          recommendedProxySettings = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;

          virtualHosts."default" = {
            listen = [
              {
                addr = "0.0.0.0";
                port = 80;
              }
            ];
            locations."/static/" = {
              alias = "/var/www/myauth/static/";
              extraConfig = "autoindex off;";
            };
            locations."= /robots.txt" = {
              alias = "/var/www/myauth/static/robots.txt";
            };
            locations."= /favicon.ico" = {
              alias = "/var/www/myauth/static/allianceauth/icons/favicon.ico";
            };
            locations."/" = {
              proxyPass = "http://127.0.0.1:8000";
            };
          };
        };

        # Application User
        users.users.allianceserver = {
          isNormalUser = true;
          extraGroups = [ ];
          home = "/home/allianceserver";
          createHome = true;
          password = "allianceauth";
        };

        # Create base directories
        systemd.tmpfiles.rules = [
          "d /var/www 0755 nginx nginx -"
          "d /var/www/myauth 0755 allianceserver nginx -"
          "d /var/www/myauth/static 0755 allianceserver nginx -"
          "d /home/allianceserver/venv 0755 allianceserver allianceserver -"
          "d /home/allianceserver/venv/auth/log 0755 allianceserver allianceserver -"
          "d /home/allianceserver/myauth/log 0755 allianceserver allianceserver -"
        ];

        # Systemd service to run supervisord for AllianceAuth
        systemd.services.allianceauth-supervisor = {
          description = "Supervisor for AllianceAuth";
          after = [
            "network.target"
            "mysql.service"
            "redis.service"
          ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "forking";
            User = "allianceserver";
            ExecStart = "${pkgs.python313Packages.supervisor}/bin/supervisord -c /home/allianceserver/myauth/supervisor.conf";
            ExecStop = "${pkgs.python313Packages.supervisor}/bin/supervisorctl -c /home/allianceserver/myauth/supervisor.conf shutdown";
            ExecReload = "${pkgs.python313Packages.supervisor}/bin/supervisorctl -c /home/allianceserver/myauth/supervisor.conf reload";
            Restart = "on-failure";
            RestartSec = "10s";
          };
        };

        networking.firewall.allowedTCPPorts = [
          80
        ];
      };
  };
}
