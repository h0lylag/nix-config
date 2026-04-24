{ pkgs, ... }:

let
  stateDir = "/var/lib/discord-relay";
  discord-relay = pkgs.callPackage ../../../pkgs/discord-relay/package.nix { inherit stateDir; };
in

{
  environment.systemPackages = [ discord-relay ];

  users.users.discord-relay = {
    isSystemUser = true;
    group = "discord-relay";
    home = stateDir;
    description = "Discord Relay Bot user";
  };

  users.groups.discord-relay = { };

  systemd.tmpfiles.rules = [
    "d ${stateDir}                  0750 discord-relay discord-relay - -"
    "d ${stateDir}/config           0750 discord-relay discord-relay - -"
    "d ${stateDir}/attachment_cache 0750 discord-relay discord-relay - -"
    "d ${stateDir}/logs             0750 discord-relay discord-relay - -"
  ];

  systemd.services.discord-relay = {
    description = "Discord Relay Bot";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${discord-relay}/bin/discord-relay --waltyrmode";
      WorkingDirectory = stateDir;
      User = "discord-relay";
      Group = "discord-relay";
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
