{
  config,
  pkgs,
  lib,
  ...
}:

let
  workshop-watcher = pkgs.callPackage ../../../pkgs/workshop-watcher/default.nix { };
  stateDir = "/var/lib/workshop-watcher"; # holds config/, db/
  watchInterval = 600; # seconds
in
{
  users.users.workshop-watcher = {
    isSystemUser = true;
    group = "workshop-watcher";
    description = "Workshop Watcher service user";
    home = stateDir;
  };
  users.groups.workshop-watcher = { };

  # Ensure state directory exists with correct ownership
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 workshop-watcher workshop-watcher - -"
    "d ${stateDir}/config 0750 workshop-watcher workshop-watcher - -"
    "d ${stateDir}/db 0750 workshop-watcher workshop-watcher - -"
  ];

  systemd.services.workshop-watcher = {
    description = "Steam Workshop Watcher";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = stateDir;
      ExecStart = lib.concatStringsSep " " [
        "${workshop-watcher}/bin/workshop-helper"
        "--watch ${toString watchInterval}"
        "--config config/config.json"
        "--modlist config/modlist.json"
        "--db db/mods.db"
      ];

      Restart = "always";
      RestartSec = 10;
      User = "workshop-watcher";
      Group = "workshop-watcher";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      LockPersonality = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      ReadWritePaths = [ stateDir ];
    };
  };
}
