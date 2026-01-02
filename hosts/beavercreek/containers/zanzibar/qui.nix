{
  config,
  pkgs,
  lib,
  ...
}:

{
  environment.systemPackages = [ pkgs.qui ];

  # Create data directory with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/qui 0755 chris users -"
  ];

  systemd.services.qui = {
    description = "Qui - Modern qBittorrent WebUI";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "chris";
      Group = "users";
      ExecStart = "${pkgs.qui}/bin/qui";
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
