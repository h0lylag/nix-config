# Prism v1, retired. It stays up at prism-v1.gravemind.sh only so that the
# Discord relay keeps its configuration pages and its catalog jobs. OpenRGB
# ingest and the Palantir workers are off. Everything here is named prism-v1
# so that Prism v2 can take the plain `prism` names on this container.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  prism-django = pkgs.local.prism-django;
  user = "prism-v1";
  host = "prism-v1.gravemind.sh";
  dbName = "prism_v1";
  redisSocket = config.services.redis.servers.prism-v1.unixSocket;
  redisUnit = "redis-prism-v1.service";
  stateDir = "/var/lib/prism-django";
  staticDir = "${stateDir}/staticfiles";
  mediaDir = "${stateDir}/media";
  releaseRoot = "/var/lib/prism-releases";
  releaseIncomingRoot = "${releaseRoot}/sftp/prism-release-ci/incoming";
  releaseProcessingRoot = "${releaseRoot}/processing";
  releasePublishedRoot = "${releaseRoot}/published";
  releaseStateRoot = "${releaseRoot}/state";
  releaseRejectedRoot = "${releaseRoot}/rejected";

  # The beat entries that still run: the relay's two catalog jobs.
  beatKeep = [
    "queue-relay-source-catalog-imports"
    "sync-relay-destination-hubs"
  ];

  releaseEnvironment = [
    "PRISM_RELEASE_ROOT=${releaseRoot}"
    "PRISM_RELEASE_INCOMING_ROOT=${releaseIncomingRoot}"
    "PRISM_RELEASE_PROCESSING_ROOT=${releaseProcessingRoot}"
    "PRISM_RELEASE_REJECTED_ROOT=${releaseRejectedRoot}"
    "PRISM_RELEASE_PUBLIC_BASE_URL=https://${host}"
    "PRISM_RELEASE_MAX_ARTIFACT_BYTES=536870912"
    "PRISM_RELEASE_DOWNLOAD_GRANT_TTL_SECONDS=600"
  ];

  # What every v1 process that reaches the database and Redis needs.
  # POSTGRES_USER and POSTGRES_PASSWORD come from the prism-env secret.
  appEnvironment = [
    "DEBUG=false"
    "ALLOWED_HOSTS=${host},localhost,127.0.0.1"
    "USE_POSTGRES=true"
    "POSTGRES_DB=${dbName}"
    "EVE_SDE_DB_NAME=eve-sde"
    "POSTGRES_HOST=localhost"
    "POSTGRES_PORT=5432"
    "REDIS_URL=unix://${redisSocket}?db=0"
    "REDIS_CACHE_URL=redis://127.0.0.1:6379/1"
    "REDIS_SESSION_URL=redis://127.0.0.1:6379/2"
    "CELERY_BROKER_URL=redis://127.0.0.1:6379/0"
    "EVEUNIVERSE_LOAD_STARGATES=true"
    "STATIC_ROOT=${staticDir}"
    "MEDIA_ROOT=${mediaDir}"
    "EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend"
    "EMAIL_HOST=smtp.gmail.com"
    "EMAIL_PORT=587"
    "EMAIL_USE_TLS=true"
    "DEFAULT_FROM_EMAIL=noreply@prism.midship.local"
    "SITE_NAME=Prism"
    "PRISM_BEAT_KEEP=${lib.concatStringsSep "," beatKeep}"
  ]
  ++ releaseEnvironment;

  hardening = {
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
    SystemCallArchitectures = "native";
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
  };

  dependsOnStores = {
    after = [
      "network-online.target"
      "postgresql.service"
      redisUnit
    ];
    wants = [ "network-online.target" ];
    requires = [
      "postgresql.service"
      redisUnit
    ];
  };

  mkCeleryWorker =
    {
      description,
      queue,
      nodeName,
      concurrency,
      maxTasksPerChild,
    }:
    dependsOnStores
    // {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      after = dependsOnStores.after ++ [ "prism-django.service" ];
      # Gate worker startup on migration/readiness checks without coupling
      # later worker restarts to routine web-only restarts.
      requisite = [ "prism-django.service" ];

      serviceConfig = hardening // {
        User = user;
        Group = user;
        Type = "simple";
        WorkingDirectory = "${prism-django}/share/prism-django";
        ExecStart = builtins.concatStringsSep " " [
          "${prism-django}/bin/prism-celery-worker"
          "--loglevel=info"
          "--pool=prefork"
          "--queues=${queue}"
          "--hostname=${nodeName}@%%h"
          "--concurrency=${toString concurrency}"
          "--prefetch-multiplier=1"
          "--max-tasks-per-child=${toString maxTasksPerChild}"
          "--events"
        ];
        Environment = appEnvironment;
        EnvironmentFile = config.sops.secrets.prism-env.path;
        Restart = "always";
        RestartSec = 10;
        ReadWritePaths = [ stateDir ];
        ReadOnlyPaths = [ releaseRoot ];
      };
    };

  prism-prod-manage = pkgs.writeShellScriptBin "prism-prod-manage" ''
    set -euo pipefail

    if [ "$(id -u)" -ne 0 ]; then
      exec ${pkgs.sudo}/bin/sudo "$0" "$@"
    fi

    exec ${pkgs.systemd}/bin/systemd-run --wait --pty --collect \
      --uid=${user} --gid=${user} \
      -p WorkingDirectory=${prism-django}/share/prism-django \
      ${
        lib.escapeShellArgs (
          lib.concatMap (value: [
            "-p"
            "Environment=${value}"
          ]) appEnvironment
        )
      } \
      -p EnvironmentFile=${config.sops.secrets.prism-env.path} \
      ${prism-django}/bin/prism-manage "$@"
  '';
in
{
  # The IDs own files in the state and release trees; keep them when the
  # account is renamed.
  users.users.${user} = {
    isSystemUser = true;
    uid = 5100;
    group = user;
    description = "Prism v1 service user";
    home = stateDir;
    extraGroups = [ config.services.redis.servers.prism-v1.group ];
  };
  # nginx needs read-only filesystem access after Django authorizes a download
  # and returns an X-Accel-Redirect into the published tree.
  users.groups.${user} = {
    gid = 5100;
    members = [ "nginx" ];
  };

  environment.systemPackages = [
    prism-prod-manage
  ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0751 ${user} ${user} - -"
    "d ${staticDir} 0755 ${user} ${user} - -"
    "d ${mediaDir} 0750 ${user} ${user} - -"
    # releaseRoot is also an OpenSSH chroot ancestor and must remain root-owned.
    "d ${releaseRoot} 0755 root root - -"
    "d ${releaseProcessingRoot} 0750 ${user} ${user} - -"
    "d ${releasePublishedRoot} 0750 ${user} ${user} - -"
    "d ${releaseStateRoot} 0750 ${user} ${user} - -"
    "d ${releaseRejectedRoot} 0750 ${user} ${user} - -"
    # Normalize data created before the service account IDs were pinned.
    "Z ${stateDir} - ${user} ${user} - -"
    "Z ${releaseProcessingRoot} - ${user} ${user} - -"
    "Z ${releasePublishedRoot} - ${user} ${user} - -"
    "Z ${releaseStateRoot} - ${user} ${user} - -"
    "Z ${releaseRejectedRoot} - ${user} ${user} - -"
  ];

  sops.secrets.prism-env = {
    sopsFile = ../../../../../secrets/prism.env;
    format = "dotenv";
    owner = user;
    group = user;
  };

  # Release uploads go to Prism v2 now, which runs its own promoter
  # (prism-v2.nix, ADR 0066). v1 keeps serving the releases it published.

  systemd.services.prism-django = dependsOnStores // {
    description = "Prism v1 Django Application (Uvicorn)";
    wantedBy = [ "multi-user.target" ];

    # Run migrations and collect static files before accepting traffic.
    preStart = ''
      echo "Running database migrations..."
      ${prism-django}/bin/prism-migrate

      echo "Collecting static files..."
      ${prism-django}/bin/prism-collectstatic
    '';

    serviceConfig = hardening // {
      User = user;
      Group = user;
      Type = "simple";
      WorkingDirectory = "${prism-django}/share/prism-django";
      ExecStart = "${prism-django}/bin/prism-uvicorn";
      TimeoutStartSec = "30min";
      ExecStartPost = pkgs.writeShellScript "prism-uvicorn-ready" ''
        for attempt in $(${pkgs.coreutils}/bin/seq 1 15); do
          if ${pkgs.curl}/bin/curl --fail --silent --show-error \
            --connect-timeout 0.5 --max-time 0.5 \
            http://127.0.0.1:8000/accounts/login/ >/dev/null; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 0.5
        done
        exit 1
      '';

      Environment = appEnvironment ++ [
        "WEB_CONCURRENCY=2"
        "DB_CONN_MAX_AGE=0"
        "FORWARDED_ALLOW_IPS=127.0.0.1"
        "UVICORN_HOST=127.0.0.1"
        "UVICORN_PORT=8000"
        "UVICORN_BACKLOG=2048"
        "UVICORN_TIMEOUT_KEEP_ALIVE=5"
        "UVICORN_TIMEOUT_GRACEFUL_SHUTDOWN=30"
        "UVICORN_LIMIT_MAX_REQUESTS=1000"
        "UVICORN_LIMIT_MAX_REQUESTS_JITTER=50"
        "UVICORN_LOG_LEVEL=info"
      ];
      EnvironmentFile = config.sops.secrets.prism-env.path;
      Restart = "always";
      RestartSec = 10;
      ReadWritePaths = [ stateDir ];
      ReadOnlyPaths = [ releaseRoot ];
    };
  };

  # The default queue takes notifications and relay work; bulk takes the
  # relay's source discovery imports.
  systemd.services.prism-celery-worker = mkCeleryWorker {
    description = "Prism v1 Celery Worker (Default Queue)";
    queue = "celery";
    nodeName = "default";
    concurrency = 2;
    maxTasksPerChild = 1000;
  };

  systemd.services.prism-celery-bulk = mkCeleryWorker {
    description = "Prism v1 Celery Worker (Bulk Queue)";
    queue = "bulk";
    nodeName = "bulk";
    concurrency = 2;
    maxTasksPerChild = 10;
  };

  systemd.services.prism-celery-beat = dependsOnStores // {
    description = "Prism v1 Celery Beat (relay jobs only)";
    wantedBy = [ "multi-user.target" ];
    after = dependsOnStores.after ++ [ "prism-django.service" ];
    # Gate Beat startup on the migrated web unit's readiness checks.
    requisite = [ "prism-django.service" ];

    serviceConfig = hardening // {
      User = user;
      Group = user;
      Type = "simple";
      WorkingDirectory = stateDir;
      ExecStart = "${prism-django}/bin/prism-celery-beat --loglevel=info --schedule=${stateDir}/celerybeat-schedule";
      Environment = appEnvironment;
      EnvironmentFile = config.sops.secrets.prism-env.path;
      Restart = "always";
      RestartSec = 10;
      ReadWritePaths = [ stateDir ];
      ReadOnlyPaths = [ releaseRoot ];
    };
  };
}
