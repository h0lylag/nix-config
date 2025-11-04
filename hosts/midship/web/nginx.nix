{ config, pkgs, ... }:

{
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

    ########################################
    # gravemind.sh (primary site)
    ########################################
    virtualHosts."gravemind.sh" = {
      default = true;
      forceSSL = true;
      useACMEHost = "gravemind.sh";
      root = "/srv/www/gravemind.sh/html";
      extraConfig = ''
        access_log /var/log/nginx/gravemind.sh.access.log combined;
        error_log /var/log/nginx/gravemind.sh.error.log warn;

        index index.html index.php;
      '';

      # PHP setup
      locations."~ ^(.+\\.php)(.*)$".extraConfig = ''
        fastcgi_pass  unix:${config.services.phpfpm.pools.php.socket};
        fastcgi_index index.php;
      '';
    };

    ########################################
    # prism.gravemind.sh (prism proxy)
    ########################################
    virtualHosts."prism.gravemind.sh" = {
      forceSSL = true;
      useACMEHost = "gravemind.sh";

      locations."/" = {
      proxyPass = "http://127.0.0.1:8000";
      proxyWebsockets = true;
      # Note: recommendedProxySettings already sets most headers, don't duplicate
      };

      locations."/downloads/" = {
      alias = "/srv/www/prism.gravemind.sh/html/downloads/";
      };
    };

    ########################################
    # mc.gravemind.sh (minecraft map proxy)
    ########################################
    virtualHosts."mc.gravemind.sh" = {
      forceSSL = true;
      useACMEHost = "gravemind.sh";

      locations."/" = {
        proxyPass = "http://localhost:8100/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };

    ########################################
    # willamettemachine.com (primary site)
    ########################################
    virtualHosts."willamettemachine.com" = {
      forceSSL = true;
      useACMEHost = "willamettemachine.com";
      root = "/srv/www/willamettemachine.com/html";
      extraConfig = ''
        access_log /var/log/nginx/willamettemachine.com.access.log combined;
        error_log /var/log/nginx/willamettemachine.com.error.log warn;

        index index.html;
      '';
    };

    ########################################
    # lambdafleet.org (primary site)
    ########################################
    virtualHosts."lambdafleet.org" = {
      forceSSL = true;
      useACMEHost = "lambdafleet.org";
      root = "/srv/www/lambdafleet.org/html";
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
        proxyPass = "http://lmdaf-auth:80";
      };
    };

    ########################################
    # multiboxxed.space (primary site)
    ########################################
    virtualHosts."multiboxxed.space" = {
      forceSSL = true;
      useACMEHost = "multiboxxed.space";
      root = "/srv/www/multiboxxed.space/html";
      extraConfig = ''
        access_log /var/log/nginx/multiboxxed.space.access.log combined;
        error_log /var/log/nginx/multiboxxed.space.error.log warn;
      '';
    };

    ########################################
    # jellyfin.gravemind.sh (media proxy)
    ########################################
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
        proxyPass = "http://lockout:8096";
        extraConfig = ''
          proxy_buffering off;
        '';
      };

      # Websocket proxy block to support Jellyfin's real-time features
      locations."/socket" = {
        proxyPass = "http://lockout:8096";
        extraConfig = ''
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_buffering off;
        '';
        proxyWebsockets = true;
      };

      # Aesthetic /web/ location block for alternate UI path
      locations."/web/" = {
        proxyPass = "http://lockout:8096";
        extraConfig = ''
          proxy_buffering off;
        '';
      };
    };

    ########################################
    # Redirects (www -> apex)
    ########################################
    # Redirect www.gravemind.sh -> gravemind.sh
    virtualHosts."www.gravemind.sh" = {
      forceSSL = true;
      useACMEHost = "gravemind.sh";
      globalRedirect = "gravemind.sh";
    };

    # Redirect www.willamettemachine.com -> willamettemachine.com
    virtualHosts."www.willamettemachine.com" = {
      forceSSL = true;
      useACMEHost = "willamettemachine.com";
      globalRedirect = "willamettemachine.com";
    };

    # Redirect www.lambdafleet.org -> lambdafleet.org
    virtualHosts."www.lambdafleet.org" = {
      forceSSL = true;
      useACMEHost = "lambdafleet.org";
      globalRedirect = "lambdafleet.org";
    };

    # Redirect www.multiboxxed.space -> multiboxxed.space
    virtualHosts."www.multiboxxed.space" = {
      forceSSL = true;
      useACMEHost = "multiboxxed.space";
      globalRedirect = "multiboxxed.space";
    };

  };

  # Nginx logs
  systemd.services.nginx.serviceConfig.ReadWritePaths = [ "/var/log/nginx/" ];
  services.logrotate.enable = true;
}
