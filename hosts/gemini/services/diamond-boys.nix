{
  config,
  pkgs,
  lib,
  ...
}:

let
  libstdcppPath = "${pkgs.stdenv.cc.cc.lib}/lib";
  diamond-boys = pkgs.callPackage ../../../pkgs/diamond-boys/default.nix { };
in

{
  # Create diamond-boys user
  users.users.diamond-boys = {
    isSystemUser = true;
    group = "diamond-boys";
    description = "Diamond Boys Bot user";
  };

  users.groups.diamond-boys = { };

  systemd.services.diamond-boys = {
    description = "Diamond Boys Bot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${diamond-boys}/bin/diamond-boys";
      WorkingDirectory = "${diamond-boys}/share/diamond-boys";
      Restart = "always";
      RestartSec = 5;
      StandardOutput = "journal";
      StandardError = "journal";
      User = "diamond-boys";
    };
  };
}
