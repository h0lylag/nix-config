{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../hardware/gemini.nix
    ../modules/common.nix
    ../modules/tailscale.nix
    ../hosts/gemini-services.nix
  ];

  # EFI Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "gemini";
  networking.useDHCP = false;
  networking.interfaces.enp1s0f0.ipv4.addresses = [
    {
      address = "147.135.105.6";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "147.135.105.254";
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];
  networking.enableIPv6 = false;

  # Setup groups ahead of making the users
  users.groups.php = { };

  # Users
  users.users = {
    nginx = {
      isSystemUser = true;
      group = "nginx";
      extraGroups = [ "log" ];
    };

    php = {
      isSystemUser = true;
      group = "php";
      extraGroups = [ "nginx" ];
    };

    dayz = {
      isNormalUser = true;
    };

    minecraft = {
      isNormalUser = true;
    };
  };


  # Firewall
  services.openssh.enable = true;
x
  networking.firewall = {
    allowedTCPPorts = [
      22
      80
      443
      2304
      2304
      2305
      2306
      25565
      25566
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
  networking.firewall.enable = false;

  environment.systemPackages = with pkgs; [
    python3
    python311Packages.pip
    python311Packages.virtualenv
    temurin-bin-21
    steamcmd
    steam-run
  ];

  # Enable LD, to allow use of dynamically linked binaries
  programs.nix-ld.enable = true;

  # SSL Certificates (ACME with Cloudflare DNS)
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@gravemind.sh";

    certs."gravemind.sh" = {
      domain = "gravemind.sh";
      extraDomainNames = [ "*.gravemind.sh" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /etc/nix-secrets/cloudflare;
    };

    certs."lambdafleet.org" = {
      domain = "lambdafleet.org";
      extraDomainNames = [ "*.lambdafleet.org" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /etc/nix-secrets/cloudflare;
    };

    certs."multiboxxed.space" = {
      domain = "multiboxxed.space";
      extraDomainNames = [ "auth.multiboxxed.space" ];
      group = "nginx";
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      credentialsFile = /etc/nix-secrets/cloudflare;
    };

  };

  # Nginx Configuration
  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
    clientMaxBodySize = "0";
    resolver.addresses = [
      "1.1.1.1"
      "8.8.8.8"
    ];

    # Use recommended settings
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;

    # gravemind vhosts
    virtualHosts."gravemind.sh" = {
      default = true;
      forceSSL = true;
      useACMEHost = "gravemind.sh";
      root = "/var/www/gravemind.sh/html";
      extraConfig = ''
        access_log /var/log/nginx/gravemind.sh.access.log combined;
        error_log /var/log/nginx/gravemind.sh.error.log warn;

        index index.html index.php;

        # Rewrite rules for old Urban Dead signature tool lmao
        rewrite ^/ud-stats/(\d+).png$ /ud-stats/stats.php?id=$1 last;
      '';

      # PHP setup
      locations."~ ^(.+\\.php)(.*)$".extraConfig = ''
        fastcgi_pass  unix:${config.services.phpfpm.pools.php.socket};
        fastcgi_index index.php;
      '';
    };

    # minecraft server map
    virtualHosts."mc.gravemind.sh" = {
      forceSSL = true;
      useACMEHost = "gravemind.sh";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8368/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };

    # lambda vhosts
    virtualHosts."lambdafleet.org" = {
      forceSSL = true;
      useACMEHost = "lambdafleet.org";
      root = "/var/www/lambdafleet.org/html";
      extraConfig = ''
        access_log /var/log/nginx/lambdafleet.org.access.log combined;
        error_log /var/log/nginx/lambdafleet.org.error.log warn;
      '';
    };

    virtualHosts."auth.lambdafleet.org" = {
      forceSSL = true;
      useACMEHost = "lambdafleet.org";
      root = "/dev/null";
      extraConfig = ''
        access_log /var/log/nginx/lambdafleet.org.access.log combined;
        error_log /var/log/nginx/lambdafleet.org.error.log warn;
      '';
      locations."/" = {
        proxyPass = "http://100.110.33.116:80$request_uri";
      };
    };

    # multiboxxed.space vhosts
    virtualHosts."multiboxxed.space" = {
      forceSSL = true;
      useACMEHost = "multiboxxed.space";
      root = "/var/www/multiboxxed.space/html";
      extraConfig = ''
        access_log /var/log/nginx/multiboxxed.space.access.log combined;
        error_log /var/log/nginx/multiboxxed.space.error.log warn;
      '';
    };

    virtualHosts."auth.multiboxxed.space" = {
      forceSSL = true;
      useACMEHost = "multiboxxed.space";
      root = "/dev/null";
      extraConfig = ''
        access_log /var/log/nginx/multiboxxed.space.access.log combined;
        error_log /var/log/nginx/multiboxxed.space.error.log warn;
      '';
      locations."/" = {
        proxyPass = "http://100.107.223.24:80$request_uri";
      };
    };

    # Jellyfin vhosts
    virtualHosts."jellyfin.gravemind.sh" = {
      forceSSL = true;
      useACMEHost = "gravemind.sh";
      root = "/dev/null";
      extraConfig = ''
        access_log /var/log/nginx/gravemind.sh.access.log combined;
        error_log /var/log/nginx/gravemind.sh.error.log warn;

        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
        add_header Cross-Origin-Opener-Policy "same-origin" always;
        add_header Cross-Origin-Embedder-Policy "require-corp" always;
        add_header Cross-Origin-Resource-Policy "same-origin" always;
        add_header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), battery=(), bluetooth=(), camera=(), clipboard-read=(), display-capture=(), document-domain=(), encrypted-media=(), gamepad=(), geolocation=(), gyroscope=(), hid=(), idle-detection=(), interest-cohort=(), keyboard-map=(), local-fonts=(), magnetometer=(), microphone=(), payment=(), publickey-credentials-get=(), serial=(), sync-xhr=(), usb=(), xr-spatial-tracking=()" always;
        add_header Content-Security-Policy "default-src https: data: blob:; img-src 'self' http://image.tmdb.org; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' https://www.gstatic.com https://www.youtube.com blob:; worker-src 'self' blob:; connect-src 'self'; object-src 'none'; frame-ancestors 'self'" always;
      '';

      # Main proxy block for Jellyfin traffic
      locations."/" = {
        proxyPass = "http://100.77.140.22:8096";
        extraConfig = ''
          proxy_buffering off;
        '';
      };

      # Websocket proxy block to support Jellyfin's real-time features
      locations."/socket" = {
        proxyPass = "http://100.77.140.22:8096";
        extraConfig = ''
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_buffering off;
        '';
        proxyWebsockets = true;
      };

      # Aesthetic /web/ location block for alternate UI path
      locations."/web/" = {
        proxyPass = "http://100.77.140.22:8096";
        extraConfig = ''
          proxy_buffering off;
        '';
      };
    };

  }; # end of nginx block

  # Nginx logs
  systemd.services.nginx.serviceConfig.ReadWritePaths = [ "/var/log/nginx/" ];
  services.logrotate.enable = true;

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

  # Ensure /run/phpfpm exists for PHP-FPM socket
  systemd.tmpfiles.rules = [
    "d /run/phpfpm 0755 root root -"
  ];

  # PHP setup
  services.phpfpm.pools.php = {
    user = "php";
    group = "php";
    phpPackage = pkgs.php;
    settings = {
      listen = "/run/phpfpm/php.sock";
      "listen.owner" = "php";
      "listen.group" = "nginx";
      "listen.mode" = "0660";
      "pm" = "dynamic";
      "pm.max_children" = 75;
      "pm.start_servers" = 10;
      "pm.min_spare_servers" = 5;
      "pm.max_spare_servers" = 20;
      "pm.max_requests" = 500;
    };
  };

  # DO NOT CHANGE
  # System version
  system.stateVersion = "24.11";
}
