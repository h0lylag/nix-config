{ config, pkgs, ... }:
{
  users.groups.wordpress = { };
  users.users.wordpress = {
    isSystemUser = true;
    group = "wordpress";
    home = "/srv/www/gravemind.sh/html/blog";
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld.skip-networking = true;
    ensureDatabases = [ "wordpress" ];
    ensureUsers = [
      {
        name = "wordpress";
        ensurePermissions."wordpress.*" = "ALL PRIVILEGES";
      }
    ];
  };

  services.phpfpm.pools.wordpress = {
    user = "wordpress";
    group = "wordpress";
    phpPackage = pkgs.php;
    settings = {
      "listen.owner" = "wordpress";
      "listen.group" = "nginx";
      "listen.mode" = "0660";
      "pm" = "dynamic";
      "pm.max_children" = 8;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
      "pm.max_requests" = 500;
      "security.limit_extensions" = ".php";
      "clear_env" = "yes";
      "php_admin_value[upload_max_filesize]" = "32M";
      "php_admin_value[post_max_size]" = "32M";
      "php_admin_value[memory_limit]" = "256M";
      "php_admin_flag[display_errors]" = "off";
      "php_admin_flag[log_errors]" = "on";
    };
  };

  services.nginx.virtualHosts."gravemind.sh".locations = {
    "= /blog".return = "301 /blog/";
    "/blog/".tryFiles = "$uri $uri/ /blog/index.php?$args";
    "~ ^/blog/(?:wp-config\\.php|readme\\.html|license\\.txt)$" = {
      priority = 80;
      return = "404";
    };
    "~ ^/blog/wp-content/(?:uploads|wflogs)/.*\\.php$" = {
      priority = 80;
      return = "404";
    };
    "~ ^/blog/.*\\.php$" = {
      priority = 90;
      extraConfig = ''
        try_files $uri =404;
        include ${config.services.nginx.package}/conf/fastcgi.conf;
        fastcgi_pass unix:${config.services.phpfpm.pools.wordpress.socket};
      '';
    };
  };

  environment.systemPackages = [ pkgs.wp-cli ];

  # WordPress owns its webroot so core, themes and plugins can update in place.
  systemd.tmpfiles.rules = [
    "d /srv/www/gravemind.sh/html/blog/wp-content/uploads 0755 wordpress wordpress -"
    "d /srv/www/gravemind.sh/html/blog/wp-content/wflogs 0750 wordpress wordpress -"
  ];

  systemd.services.wordpress-cron = {
    description = "Run scheduled WordPress tasks";
    after = [ "mysql.service" ];
    requires = [ "mysql.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "wordpress";
      Group = "wordpress";
      ExecStart = "${pkgs.wp-cli}/bin/wp --path=/srv/www/gravemind.sh/html/blog cron event run --due-now";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [
        "/srv/www/gravemind.sh/html/blog"
      ];
    };
  };
  systemd.timers.wordpress-cron = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitInactiveSec = "5m";
    };
  };
}
