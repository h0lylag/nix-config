{ config, pkgs, ... }:

let
  pkg = pkgs.callPackage ../../../pkgs/eve-public-contracts/package.nix { };
  svcName = "eve-public-contracts";
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
    description = "EVE Online public contracts fetcher and notifier";
    after = [
      "network-online.target"
      "postgresql.service"
    ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
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

    script = ''
      ${pkg}/bin/${svcName} --all-regions --notify --min-price 800m
    '';
  };

  systemd.timers.${svcName} = {
    description = "EVE Online public contracts timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/10";
      Persistent = true;
    };
  };
}
