{ ... }:

{
  services.nginx = {
    enable = true;
    clientMaxBodySize = "0";
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."img.cat" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
          extraParameters = [ "default_server" ];
        }
      ];

      # Named fallback location for Django — used by try_files in /i/ and /t/
      # proxy_set_header Host must be explicit here: any proxy_set_header in a
      # location block overrides ALL inherited headers from recommendedProxySettings.
      extraConfig = ''
        location @gunicorn {
          proxy_pass http://127.0.0.1:8000;
          proxy_set_header Host $host;
          proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
          proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        }
      '';

      # Direct image/thumbnail file serving; falls back to Django for slug-based detail views
      locations."/i/" = {
        alias = "/srv/www/imgcat/media/images/";
        extraConfig = ''
          try_files $uri @gunicorn;
          autoindex off;
        '';
      };

      locations."/t/" = {
        alias = "/srv/www/imgcat/media/thumbnails/";
        extraConfig = ''
          try_files $uri @gunicorn;
          autoindex off;
        '';
      };

      locations."/static/" = {
        alias = "/srv/www/imgcat/static/";
        extraConfig = "autoindex off;";
      };

      locations."/media/" = {
        alias = "/srv/www/imgcat/media/";
        extraConfig = "autoindex off;";
      };

      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        extraConfig = ''
          proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
          proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        '';
      };
    };
  };
}
