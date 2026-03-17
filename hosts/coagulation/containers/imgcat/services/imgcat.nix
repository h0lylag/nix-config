{ pkgs, lib, config, ... }:

let
  imgcat = pkgs.callPackage ../../../../pkgs/imgcat-django/default.nix { };
in
{
  sops.secrets.imgcat-env = {
    sopsFile = ../../../../secrets/imgcat.env;
    format = "dotenv";
    owner = "imgcat";
    group = "imgcat";
  };

  systemd.services.imgcat = {
    description = "imgcat Django image hosting";
    after = [
      "network.target"
      "postgresql.service"
    ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "imgcat";
      Group = "imgcat";

      # /var/lib/imgcat/ for media, staticfiles, logs
      StateDirectory = "imgcat";
      StateDirectoryMode = "0750";

      EnvironmentFile = config.sops.secrets.imgcat-env.path;

      ExecStartPre = [
        "${imgcat}/bin/imgcat-migrate"
        "${imgcat}/bin/imgcat-collectstatic"
      ];
      ExecStart = "${imgcat}/bin/imgcat-gunicorn";

      Restart = "on-failure";
      RestartSec = "10";
    };
  };
}
