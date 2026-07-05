{ ... }:

let
  staticDir = "/var/lib/prism-django/staticfiles";
  downloadsDir = "/srv/www/prism.gravemind.sh/html/downloads";
in
{
  networking.firewall.allowedTCPPorts = [ 80 ];

  systemd.tmpfiles.rules = [
    "d /srv/www 0755 root root - -"
    "d /srv/www/prism.gravemind.sh 0755 root root - -"
    "d /srv/www/prism.gravemind.sh/html 0755 root root - -"
    "d ${downloadsDir} 0750 prism prism - -"
  ];

  systemd.services.nginx = {
    after = [ "prism-django.service" ];
    wants = [ "prism-django.service" ];
    serviceConfig.SupplementaryGroups = [ "prism" ];
  };

  services.nginx = {
    enable = true;
    clientMaxBodySize = "0";
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    commonHttpConfig = ''
      map $http_x_forwarded_proto $prism_forwarded_proto {
        default $http_x_forwarded_proto;
        "" $scheme;
      }
    '';

    virtualHosts."prism.gravemind.sh" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];

      locations."/static/" = {
        alias = "${staticDir}/";
        extraConfig = ''
          expires 1y;
          add_header Cache-Control "public, immutable";
          access_log off;
          autoindex off;
        '';
      };

      locations."/internal-downloads/" = {
        alias = "${downloadsDir}/";
        extraConfig = ''
          internal;
        '';
      };

      locations."/downloads/" = {
        proxyPass = "http://127.0.0.1:8000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $prism_forwarded_proto;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Server $hostname;
          proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        '';
      };

      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $prism_forwarded_proto;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Server $hostname;
          proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
        '';
      };
    };
  };
}
