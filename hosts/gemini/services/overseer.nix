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
  systemd.services.overseer = {
    description = "Overseer Discord Bot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "/opt/overseer/result/bin/overseer";
      WorkingDirectory = "/opt/overseer";
      Environment = "LD_LIBRARY_PATH=${libstdcppPath}";
      Restart = "always";
      RestartSec = 15;
      StandardOutput = "journal";
      StandardError = "journal";
      User = "chris";
    };
  };
}
