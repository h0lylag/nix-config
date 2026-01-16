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

    # Fix proxy_headers_hash warning
    commonHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
    '';

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

      # Serve static files directly from nginx (faster than Django/Gunicorn)
      locations."/static/" = {
        alias = "/var/lib/prism-django/staticfiles/";
        extraConfig = ''
          expires 1y;
          add_header Cache-Control "public, immutable";
          access_log off;
        '';
      };

      # Internal location for authenticated downloads (X-Accel-Redirect)
      # This is NOT accessible directly from outside - only via Django redirects
      locations."/internal-downloads/" = {
        alias = "/srv/www/prism.gravemind.sh/html/downloads/";
        extraConfig = ''
          internal;
        '';
      };

      # Django-authenticated downloads endpoint
      # Requests to /downloads/ go to Django which checks login and returns X-Accel-Redirect
      locations."/downloads/" = {
        proxyPass = "http://127.0.0.1:8000";
        proxyWebsockets = true;
      };

      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        proxyWebsockets = true;
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
    # mc.gravemind.sh (minecraft map proxy)
    ########################################
    virtualHosts."sven.gravemind.sh" = {
      forceSSL = true;
      useACMEHost = "gravemind.sh";
      root = "/srv/www/sven/html";
      extraConfig = ''
        access_log /var/log/nginx/sven.log combined;
        error_log /var/log/nginx/sven.error.log warn;

        index index.html index.php;
      '';
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
    # evepreview.com
    ########################################
    virtualHosts."evepreview.com" = {
      forceSSL = true;
      useACMEHost = "evepreview.com";
      root = "/srv/www/evepreview.com/html";

      # Serve .well-known directly to support Flathub verification
      locations."/.well-known/" = {
        alias = "/srv/www/evepreview.com/html/.well-known/";
      };

      # Redirect everything else to epm.sh
      locations."/" = {
        return = "301 https://epm.sh$request_uri";
      };

      extraConfig = ''
        access_log /var/log/nginx/evepreview.com.access.log combined;
        error_log /var/log/nginx/evepreview.com.error.log warn;
      '';
    };

    ########################################
    # manager.evepreview.com
    ########################################
    virtualHosts."manager.evepreview.com" = {
      forceSSL = true;
      useACMEHost = "evepreview.com";
      globalRedirect = "epm.sh";
    };

    ########################################
    # epm.sh
    ########################################
    virtualHosts."epm.sh" = {
      forceSSL = true;
      useACMEHost = "epm.sh";
      root = "/srv/www/epm.sh/html";
      extraConfig = ''
        access_log /var/log/nginx/epm.sh.access.log combined;
        error_log /var/log/nginx/epm.sh.error.log warn;

        index index.html;
        try_files $uri $uri.html $uri/ =404;
      '';
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

        # Fixes some issue with WebOS clients - Stanley asked me to update this
        # https://github.com/jellyfin/jellyfin-webos/issues/63#issuecomment-1764320364
        #add_header X-Frame-Options "SAMEORIGIN";
        add_header Cross-Origin-Resource-Policy "cross-origin" always;

        add_header X-Content-Type-Options "nosniff";
        add_header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), battery=(), bluetooth=(), camera=(), clipboard-read=(), display-capture=(), document-domain=(), encrypted-media=(), gamepad=(), geolocation=(), gyroscope=(), hid=(), idle-detection=(), interest-cohort=(), keyboard-map=(), local-fonts=(), magnetometer=(), microphone=(), payment=(), publickey-credentials-get=(), serial=(), sync-xhr=(), usb=(), xr-spatial-tracking=()" always;
        add_header Content-Security-Policy "default-src https: data: blob: ; img-src 'self' https://* ; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' https://www.gstatic.com https://www.youtube.com blob:; worker-src 'self' blob:; connect-src 'self'; object-src 'none'; font-src 'self'";
      '';

      # Main proxy block for Jellyfin traffic
      locations."/" = {
        proxyPass = "http://sanctuary:8096";
        extraConfig = ''
          proxy_buffering off;
          proxy_pass_header Authorization;
          proxy_set_header X-Forwarded-Protocol \$scheme;
        '';
      };

      # Websocket proxy block to support Jellyfin's real-time features
      locations."/socket" = {
        proxyPass = "http://sanctuary:8096";
        extraConfig = ''
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_set_header X-Forwarded-Protocol \$scheme;
          proxy_pass_header Authorization;
          proxy_buffering off;
        '';
        proxyWebsockets = true;
      };

      # Aesthetic /web/ location block for alternate UI path
      locations."/web/" = {
        proxyPass = "http://sanctuary:8096";
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

    # Redirect www.evepreview.com -> evepreview.com
    virtualHosts."www.evepreview.com" = {
      forceSSL = true;
      useACMEHost = "evepreview.com";
      globalRedirect = "evepreview.com";
    };

    # Redirect www.epm.sh -> epm.sh
    virtualHosts."www.epm.sh" = {
      forceSSL = true;
      useACMEHost = "epm.sh";
      globalRedirect = "epm.sh";
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
