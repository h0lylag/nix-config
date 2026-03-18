{ ... }:

{
  services.nginx = {
    enable = true;
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
      extraConfig = ''
        location @gunicorn {
          proxy_pass http://127.0.0.1:8000;
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
      };
    };
  };
}
