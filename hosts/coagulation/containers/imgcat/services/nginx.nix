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

      locations."/i/" = {
        alias = "/srv/www/imgcat/media/images/";
        extraConfig = "autoindex off;";
      };

      locations."/t/" = {
        alias = "/srv/www/imgcat/media/thumbnails/";
        extraConfig = "autoindex off;";
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
