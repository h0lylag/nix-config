{ config, pkgs, ... }:

let
  stateDir = "/var/lib/discord-relay";
  steak-bot = pkgs.callPackage ../../../pkgs/steak-bot/package.nix { inherit stateDir; };
in

{
  environment.systemPackages = [ steak-bot ];

  sops.secrets.discord-relay-env = {
    sopsFile = ../../../secrets/discord-relay.env;
    format = "dotenv";
    owner = "discord-relay";
    group = "discord-relay";
  };

  systemd.services.steak-bot = {
    description = "Steak-Bot Relay Server Operator";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${steak-bot}/bin/steak-bot";
      WorkingDirectory = stateDir;
      User = "discord-relay";
      Group = "discord-relay";
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
