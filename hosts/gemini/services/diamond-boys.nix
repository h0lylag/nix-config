{
  config,
  pkgs,
  lib,
  ...
}:

let
  libstdcppPath = "${pkgs.stdenv.cc.cc.lib}/lib";
in

{
  systemd.services.diamond-boys = {
    description = "Diamond Boys Bot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python -u /opt/diamond_boys/diamond-boys.py";
      WorkingDirectory = "/opt/diamond_boys";
      Restart = "always";
      RestartSec = 5;
      StandardOutput = "journal";
      StandardError = "journal";
      User = "chris";
    };
  };
}
