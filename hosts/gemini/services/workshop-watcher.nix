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
      # Use --watch flag only; paths are set via environment variables
      ExecStart = "${workshop-watcher}/bin/workshop-watcher --watch ${toString watchInterval}";

      # Environment variables for configuration
      Environment = [
        # Sensitive configuration (can be moved to sops-nix/agenix)
        "DISCORD_WEBHOOK=https://discord.com/api/webhooks/1405433053865578638/pjoTVZIoBXWtC_m1166-JqjMAmIbgpsJ6uHZlet5knbqmuRzgD08DHLXw7oFT1BojJcH"
        "STEAM_API_KEY=952610D5F561C4B3FE0F16AF8350BFC4"
        "PING_ROLES=1387444657562193960"
        
        # File paths - ensures data persists outside Nix store
        "CONFIG_PATH=${stateDir}/config/config.json"
        "MODLIST_PATH=${stateDir}/config/modlist.json"
        "DB_PATH=${stateDir}/db/mods.db"
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
