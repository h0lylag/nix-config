{ config, pkgs, ... }:

let
  stateDir = "/var/lib/discord-relay";
  discord-relay = pkgs.callPackage ../../../../../pkgs/discord-relay/package.nix {
    inherit stateDir;
  };
  discord-relay-prod = pkgs.writeShellScriptBin "discord-relay-prod" (
    builtins.concatStringsSep "\n" [
      "set -euo pipefail"
      ""
      "if [ \"$(id -u)\" -ne 0 ]; then"
      "  exec ${pkgs.sudo}/bin/sudo \"$0\" \"$@\""
      "fi"
      ""
      "exec ${pkgs.systemd}/bin/systemd-run --wait --pty --collect --uid=discord-relay --gid=discord-relay -p WorkingDirectory=${stateDir} -p EnvironmentFile=${config.sops.secrets.discord-relay-env.path} ${discord-relay}/bin/discord-relay \"$@\""
    ]
  );
in

{
  environment.systemPackages = [
    discord-relay
    discord-relay-prod
  ];

  sops.secrets.discord-relay-env = {
    sopsFile = ../../../../../secrets/discord-relay.env;
    format = "dotenv";
    owner = "discord-relay";
    group = "discord-relay";
  };

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

    serviceConfig = {
      Type = "simple";
      ExecStart = "${discord-relay}/bin/discord-relay --waltyrmode";
      WorkingDirectory = stateDir;
      EnvironmentFile = config.sops.secrets.discord-relay-env.path;
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
