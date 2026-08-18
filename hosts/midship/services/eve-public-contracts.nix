{ config, pkgs, ... }:

let
  pkg = pkgs.callPackage ../../../pkgs/eve-public-contracts/package.nix { };
  svcName = "eve-public-contracts";
  commonServiceConfig = {
    User = svcName;
    Group = svcName;
    EnvironmentFile = config.sops.secrets.eve-public-contracts-env.path;
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
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
  };
in
{
  environment.systemPackages = [ pkg ];

  sops.secrets.eve-public-contracts-env = {
    sopsFile = ../../../secrets/eve-public-contracts.env;
    format = "dotenv";
    owner = svcName;
    group = svcName;
  };

  users.users.${svcName} = {
    isSystemUser = true;
    group = svcName;
    description = "EVE public contracts service user";
  };

  users.groups.${svcName} = { };

  systemd.services.${svcName} = {
    description = "EVE Online public contracts fetcher";
    after = [
      "network-online.target"
      "postgresql.service"
    ];
    wants = [ "network-online.target" ];
    environment.DISCORD_DELIVERY_MODE = "bot";

    serviceConfig = commonServiceConfig // {
      Type = "oneshot";
      # Ingest only; the persistent bot service drains queued feed deliveries.
      ExecStart = "${pkg}/bin/${svcName} --all-regions --min-price 800m";
    };
  };

  systemd.services."${svcName}-bot" = {
    description = "EVE Online public contracts Discord bot";
    after = [
      "network-online.target"
      "postgresql.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.DISCORD_DELIVERY_MODE = "bot";

    serviceConfig = commonServiceConfig // {
      Type = "simple";
      ExecStart = "${pkg}/bin/${svcName}-bot";
      Restart = "always";
      RestartSec = "15s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.timers.${svcName} = {
    description = "EVE Online public contracts timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "0";
      OnUnitActiveSec = "35min";
      Persistent = true;
    };
  };
}
