{
  config,
  pkgs,
  ...
}:

let
  serviceName = "eve-fundraiser";
  stateDir = "/var/lib/${serviceName}";
  package = pkgs.callPackage ../../../pkgs/eve-fundraiser/package.nix { };

  environment = {
    BANK_CHARACTER_NAME = "Titan Fund Bank";
    DATABASE_PATH = "${stateDir}/fundraiser.db";
    ESI_USER_AGENT = "Titan Fundraiser / admin@gravemind.sh";
    EVE_REDIRECT_URI = "https://gravemind.sh/titan-fund/auth/callback";
    FUNDRAISER_GOAL_ISK = "150000000000";
  };

  hardening = {
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
    ReadWritePaths = [ stateDir ];
    UMask = "0077";
  };
in
{
  environment.systemPackages = [ package ];

  sops.secrets.eve-fundraiser-env = {
    sopsFile = ../../../secrets/eve-fundraiser.env;
    format = "dotenv";
    owner = serviceName;
    group = serviceName;
  };

  users.users.${serviceName} = {
    isSystemUser = true;
    group = serviceName;
    home = stateDir;
    description = "EVE titan fundraiser service user";
  };

  users.groups.${serviceName} = { };

  systemd.services.${serviceName} = {
    description = "EVE titan fundraiser web application";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = environment // {
      GUNICORN_CMD_ARGS = builtins.concatStringsSep " " [
        "--bind=127.0.0.1:5000"
        "--workers=2"
        "--access-logfile=-"
        "--error-logfile=-"
      ];
    };

    serviceConfig = hardening // {
      Type = "simple";
      User = serviceName;
      Group = serviceName;
      StateDirectory = serviceName;
      StateDirectoryMode = "0750";
      WorkingDirectory = stateDir;
      EnvironmentFile = config.sops.secrets.eve-fundraiser-env.path;
      ExecStart = "${package}/bin/eve-fundraiser";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  systemd.services.eve-fundraiser-sync = {
    description = "Synchronize the EVE titan fundraiser wallet";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    inherit environment;

    serviceConfig = hardening // {
      Type = "oneshot";
      User = serviceName;
      Group = serviceName;
      StateDirectory = serviceName;
      StateDirectoryMode = "0750";
      WorkingDirectory = stateDir;
      EnvironmentFile = config.sops.secrets.eve-fundraiser-env.path;
      ExecStart = "${package}/bin/eve-fundraiser-sync";
    };
  };

  systemd.timers.eve-fundraiser-sync = {
    description = "Hourly EVE titan fundraiser wallet synchronization";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Persistent = true;
      RandomizedDelaySec = "5min";
    };
  };
}
