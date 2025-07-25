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
}
