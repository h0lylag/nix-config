{
  config,
  pkgs,
  lib,
  ...
}:

let
  libstdcppPath = "${pkgs.stdenv.cc.cc.lib}/lib";
  discord-relay = pkgs.callPackage ../../../pkgs/discord-relay/default.nix { };
in

{
  # Create discord-relay user
  users.users.discord-relay = {
    isSystemUser = true;
    group = "discord-relay";
    home = "/home/discord-relay";
    createHome = true;
    description = "Discord Relay Bot user";
  };

  users.groups.discord-relay = { };

  systemd.services.discord-relay = {
    description = "Discord Relay Bot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${discord-relay}/bin/discord-relay --waltyrmode"; # waltyrmode starts all accounts at once
      WorkingDirectory = "/home/discord-relay";
      Environment = [
        "LD_LIBRARY_PATH=${libstdcppPath}"
      ];
      Restart = "always";
      RestartSec = 15;
      StandardOutput = "journal";
      StandardError = "journal";
      User = "discord-relay";
      Group = "discord-relay";
    };
  };
}
