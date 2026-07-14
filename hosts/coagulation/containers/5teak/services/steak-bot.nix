{ config, pkgs, ... }:

let
  stateDir = "/var/lib/discord-relay";
  steak-bot = pkgs.callPackage ../../../../../pkgs/steak-bot/package.nix { inherit stateDir; };
in

{
  environment.systemPackages = [ steak-bot ];

  systemd.services.steak-bot = {
    description = "Steak-Bot Relay Server Operator";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "postgresql.service"
      "redis-prism.service"
    ];
    wants = [
      "network-online.target"
      "postgresql.service"
      "redis-prism.service"
    ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${steak-bot}/bin/steak-bot";
      WorkingDirectory = stateDir;
      User = "discord-relay";
      Group = "discord-relay";
      Environment = [
        "PRISM_SSE_REDIS_URL=redis://127.0.0.1:6379/0"
      ];
      EnvironmentFile = config.sops.secrets.discord-relay-env.path;
      Restart = "always";
      RestartSec = 15;
      StandardOutput = "journal";
      StandardError = "journal";
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
