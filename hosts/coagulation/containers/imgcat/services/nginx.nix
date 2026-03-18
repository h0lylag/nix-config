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
          default = true;
        }
      ];

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
