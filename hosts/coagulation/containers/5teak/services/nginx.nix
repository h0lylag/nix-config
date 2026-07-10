{ ... }:

let
  staticDir = "/var/lib/prism-django/staticfiles";
  downloadsDir = "/srv/www/prism.gravemind.sh/html/downloads";
  releasePublishedDir = "/var/lib/prism-releases/published";
in
{
  networking.firewall.allowedTCPPorts = [ 80 ];

  systemd.tmpfiles.rules = [
    "d /srv/www 0755 root root - -"
    "d /srv/www/prism.gravemind.sh 0755 root root - -"
    "d /srv/www/prism.gravemind.sh/html 0755 root root - -"
    "d ${downloadsDir} 0750 prism prism - -"
    # Preserve Lighthouse ownership when the Prism service UID/GID is pinned.
    "Z ${downloadsDir} - prism prism - -"
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

      # Django resolves validated Prism releases to this internal URI via
      # X-Accel-Redirect.
      locations."/internal-prism-releases/" = {
        alias = "${releasePublishedDir}/";
        extraConfig = ''
          internal;
          autoindex off;
          access_log off;
          log_not_found off;
        '';
      };

      # Capability tokens are query parameters; exclude them from nginx access logs.
      locations."= /api/releases/download" = {
        extraConfig = ''
          access_log off;
          add_header Referrer-Policy "no-referrer" always;
          return 308 /api/releases/download/$is_args$args;
        '';
      };

      locations."= /api/releases/download/" = {
        proxyPass = "http://127.0.0.1:8000";
        extraConfig = ''
          access_log off;
          add_header Referrer-Policy "no-referrer" always;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $prism_forwarded_proto;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Server $hostname;
          proxy_set_header CF-Connecting-IP $http_cf_connecting_ip;
          proxy_connect_timeout 5s;
          proxy_read_timeout 75s;
          proxy_send_timeout 75s;
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
          proxy_connect_timeout 5s;
          proxy_read_timeout 75s;
          proxy_send_timeout 75s;
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
          proxy_connect_timeout 5s;
          proxy_read_timeout 75s;
          proxy_send_timeout 75s;
        '';
      };
    };
  };
}
