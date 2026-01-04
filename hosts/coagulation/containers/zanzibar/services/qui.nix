{
  config,
  pkgs,
  lib,
  ...
}:

{
  environment.systemPackages = [ pkgs.qui ];

  users.users.qui = {
    isSystemUser = true;
    group = "media";
  };

  systemd.services.qui = {
    description = "Qui - Modern qBittorrent WebUI";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "qui";
      Group = "media";
      UMask = "0002";

      # Automatically create /var/lib/qui with correct permissions
      StateDirectory = "qui";
      WorkingDirectory = "/var/lib/qui";

      ExecStart = "${pkgs.qui}/bin/qui serve";
      Restart = "always";
      RestartSec = "10";
    };

    environment = {
      QUI__PORT = "7476";
      QUI__HOST = "0.0.0.0";
      QUI__DATA_DIR = "/var/lib/qui";
    };
  };

  networking.firewall.allowedTCPPorts = [ 7476 ];
}
