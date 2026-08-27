{
  config,
  nixpkgs-unstable,
  pkgs,
  ...
}:

let
  serviceName = "eve-price-check";
  publicHost = "epc.gravemind.sh";
  bindAddress = "127.0.0.1:3000";
  unstablePkgs = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  package = unstablePkgs.callPackage ../../../pkgs/eve-price-check/package.nix { };

  databaseEnvironment = {
    LOG_FILTER = "eve_price_check=info";
  };
  esiEnvironment = databaseEnvironment // {
    ESI_USER_AGENT = "eve-price-check/0.1 (https://${publicHost})";
  };
  webEnvironment = databaseEnvironment // {
    BIND_ADDRESS = bindAddress;
    MARKET_MAX_STALENESS = "1800";
    PUBLIC_BASE_URL = "https://${publicHost}";
    TRUSTED_PROXY_IPS = "127.0.0.1";
  };

  hardening = {
    User = serviceName;
    Group = serviceName;
    NoNewPrivileges = true;
    PrivateTmp = true;
    EnvironmentFile = config.sops.secrets.eve-price-check-env.path;
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
    UMask = "0077";
  };
in
{
  environment.systemPackages = [ package ];

  users.users.${serviceName} = {
    isSystemUser = true;
    group = serviceName;
    description = "EVE price check service user";
  };
  users.groups.${serviceName} = { };

  sops.secrets.eve-price-check-env = {
    sopsFile = ../../../secrets/eve-price-check.env;
    format = "dotenv";
    owner = serviceName;
    group = serviceName;
  };

  services.postgresql = {
    ensureDatabases = [ serviceName ];
    ensureUsers = [
      {
        name = serviceName;
        ensureDBOwnership = true;
      }
    ];
  };

  systemd.services."${serviceName}-migrate" = {
    description = "Migrate the EVE price check database";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];

    environment = databaseEnvironment;
    serviceConfig = hardening // {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${package}/bin/eve-price-check database migrate";
    };
  };

  systemd.services."${serviceName}-sde-update" = {
    description = "Update EVE price check static data";
    after = [
      "network-online.target"
      "${serviceName}-migrate.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "${serviceName}-migrate.service" ];

    environment = esiEnvironment;
    serviceConfig = hardening // {
      Type = "oneshot";
      ExecStart = "${package}/bin/eve-price-check sde update";
    };
  };

  systemd.timers."${serviceName}-sde-update" = {
    description = "Periodic EVE price check static data update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "12h";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  systemd.services."${serviceName}-web" = {
    description = "EVE price check web application";
    after = [
      "network-online.target"
      "${serviceName}-migrate.service"
      "${serviceName}-sde-update.service"
    ];
    wants = [
      "network-online.target"
      "${serviceName}-sde-update.service"
    ];
    requires = [ "${serviceName}-migrate.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = webEnvironment;
    serviceConfig = hardening // {
      Type = "simple";
      ExecStart = "${package}/bin/eve-price-check serve";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  systemd.services."${serviceName}-market" = {
    description = "EVE price check ESI market worker";
    after = [
      "network-online.target"
      "${serviceName}-migrate.service"
      "${serviceName}-sde-update.service"
    ];
    wants = [
      "network-online.target"
      "${serviceName}-sde-update.service"
    ];
    requires = [ "${serviceName}-migrate.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = esiEnvironment;
    serviceConfig = hardening // {
      Type = "simple";
      ExecStart = "${package}/bin/eve-price-check market run";
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
