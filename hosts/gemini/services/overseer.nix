{
  config,
  pkgs,
  lib,
  ...
}:

let
  libstdcppPath = "${pkgs.stdenv.cc.cc.lib}/lib";
  overseer = pkgs.callPackage ../../../pkgs/overseer/default.nix { };
in

{
  systemd.services.overseer = {
    description = "Overseer Discord Bot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${overseer}/bin/overseer";
      # If the bot needs a writable working directory, set it here.
      # WorkingDirectory = "/var/lib/overseer";
      Environment = "LD_LIBRARY_PATH=${libstdcppPath}";
      Restart = "always";
      RestartSec = 15;
      StandardOutput = "journal";
      StandardError = "journal";
      User = "chris";
    };
  };
}
