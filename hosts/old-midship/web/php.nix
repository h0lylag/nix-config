{ config, pkgs, ... }:

{
  users.groups.php = { };

  users.users.php = {
    isSystemUser = true;
    group = "php";
    extraGroups = [ "nginx" ];
  };

  systemd.tmpfiles.rules = [
    "d /run/phpfpm 0755 root root -"
  ];

  # PHP setup
  services.phpfpm.pools.php = {
    user = "php";
    group = "php";
    phpPackage = pkgs.php;
    settings = {
      listen = "/run/phpfpm/php.sock";
      "listen.owner" = "php";
      "listen.group" = "nginx";
      "listen.mode" = "0660";
      "pm" = "dynamic";
      "pm.max_children" = 75;
      "pm.start_servers" = 10;
      "pm.min_spare_servers" = 5;
      "pm.max_spare_servers" = 20;
      "pm.max_requests" = 500;
      "security.limit_extensions" = ".php";
      "chdir" = "/";
      "clear_env" = "yes";
      "env[PATH]" = "/run/current-system/sw/bin";
      "env[TMP]" = "/tmp";
      "env[TMPDIR]" = "/tmp";
      "php_admin_value[opcache.enable]" = "1";
    };
  };
}
