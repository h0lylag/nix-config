{
  config,
  pkgs,
  lib,
  ...
}:

let
  prism-django = pkgs.callPackage ../../../../../pkgs/prism-django/package.nix { };
  stateDir = "/var/lib/prism-django";
  releaseRoot = "/var/lib/prism-releases";
  releaseIncomingRoot = "${releaseRoot}/sftp/prism-release-ci/incoming";
  releaseProcessingRoot = "${releaseRoot}/processing";
  releasePublishedRoot = "${releaseRoot}/published";
  releaseStateRoot = "${releaseRoot}/state";
  releaseRejectedRoot = "${releaseRoot}/rejected";
  releaseEnvironment = [
    "PRISM_RELEASE_ROOT=${releaseRoot}"
    "PRISM_RELEASE_INCOMING_ROOT=${releaseIncomingRoot}"
    "PRISM_RELEASE_PROCESSING_ROOT=${releaseProcessingRoot}"
    "PRISM_RELEASE_REJECTED_ROOT=${releaseRejectedRoot}"
    "PRISM_RELEASE_PUBLIC_BASE_URL=https://prism.gravemind.sh"
    "PRISM_RELEASE_MAX_ARTIFACT_BYTES=536870912"
    "PRISM_RELEASE_DOWNLOAD_GRANT_TTL_SECONDS=600"
  ];
  releaseEnvironmentProperties = lib.escapeShellArgs (
    lib.concatMap (value: [
      "-p"
      "Environment=${value}"
    ]) releaseEnvironment
  );
  prism-prod-manage = pkgs.writeShellScriptBin "prism-prod-manage" (
    builtins.concatStringsSep "\n" [
      "set -euo pipefail"
      ""
      "if [ \"$(id -u)\" -ne 0 ]; then"
      "  exec ${pkgs.sudo}/bin/sudo \"$0\" \"$@\""
      "fi"
      ""
      "exec ${pkgs.systemd}/bin/systemd-run --wait --pty --collect --uid=prism --gid=prism -p WorkingDirectory=${prism-django}/share/prism-django -p Environment=DEBUG=false -p Environment=USE_POSTGRES=true -p Environment=POSTGRES_DB=prism -p Environment=POSTGRES_HOST=localhost -p Environment=POSTGRES_PORT=5432 -p Environment=REDIS_URL=unix:///run/redis-prism/redis.sock?db=0 -p Environment=REDIS_CACHE_URL=redis://127.0.0.1:6379/1 -p Environment=REDIS_SESSION_URL=redis://127.0.0.1:6379/2 -p Environment=CELERY_BROKER_URL=redis://127.0.0.1:6379/0 -p Environment=EVEUNIVERSE_LOAD_STARGATES=true ${releaseEnvironmentProperties} -p EnvironmentFile=${config.sops.secrets.prism-env.path} ${prism-django}/bin/prism-manage \"$@\""
    ]
  );
  releasePromoter = pkgs.writeShellApplication {
    name = "prism-release-promote-ready";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
    ];
    text = ''
      exec 9>"${releaseStateRoot}/promoter.lock"
      if ! flock --nonblock 9; then
        echo "Another Prism release promoter is active; exiting." >&2
        exit 0
      fi

      status=0
      while IFS= read -r -d "" submission; do
        if ! ${prism-django}/bin/prism-release-promoter \
          --submission "$submission" \
          --release-root ${lib.escapeShellArg releaseRoot} \
          --processing-root ${lib.escapeShellArg releaseProcessingRoot} \
          --rejected-root ${lib.escapeShellArg releaseRejectedRoot}; then
          echo "Prism release promotion failed for $submission" >&2
          status=1
        fi
      done < <(find ${lib.escapeShellArg releaseIncomingRoot} \
        -mindepth 1 -maxdepth 1 -type d -name '*.ready' -print0 | sort -z)

      while IFS= read -r -d "" submission; do
        if ! ${prism-django}/bin/prism-release-resumer \
          --submission "$submission" \
          --release-root ${lib.escapeShellArg releaseRoot} \
          --processing-root ${lib.escapeShellArg releaseProcessingRoot} \
          --rejected-root ${lib.escapeShellArg releaseRejectedRoot}; then
          echo "Prism release resumption failed for $submission" >&2
          status=1
        fi
      done < <(find ${lib.escapeShellArg releaseProcessingRoot} \
        -mindepth 1 -maxdepth 1 -type d -name '*.processing' -print0 | sort -z)

      exit "$status"
    '';
  };
  staticDir = "${stateDir}/staticfiles";
  mediaDir = "${stateDir}/media";
in
{
  users.users.prism = {
    isSystemUser = true;
    uid = 5100;
    group = "prism";
    description = "Prism Django service user";
    home = stateDir;
  };
  # nginx needs read-only filesystem access after Django authorizes a download
  # and returns an X-Accel-Redirect into the published tree.
  users.groups.prism = {
    gid = 5100;
    members = [ "nginx" ];
  };

  environment.systemPackages = [
    prism-prod-manage
    releasePromoter
  ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0751 prism prism - -"
    "d ${staticDir} 0755 prism prism - -"
    "d ${mediaDir} 0750 prism prism - -"
    # releaseRoot is also an OpenSSH chroot ancestor and must remain root-owned.
    "d ${releaseRoot} 0755 root root - -"
    "d ${releaseProcessingRoot} 0750 prism prism - -"
    "d ${releasePublishedRoot} 0750 prism prism - -"
    "d ${releaseStateRoot} 0750 prism prism - -"
    "d ${releaseRejectedRoot} 0750 prism prism - -"
    # Normalize data created before the service account IDs were pinned.
    "Z ${stateDir} - prism prism - -"
    "Z ${releaseProcessingRoot} - prism prism - -"
    "Z ${releasePublishedRoot} - prism prism - -"
    "Z ${releaseStateRoot} - prism prism - -"
    "Z ${releaseRejectedRoot} - prism prism - -"
  ];

  sops.secrets.prism-env = {
    sopsFile = ../../../../../secrets/prism.env;
    format = "dotenv";
    owner = "prism";
    group = "prism";
  };

  systemd.paths.prism-release-promoter = {
    description = "Watch for completed Prism release submissions";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = [
        releaseIncomingRoot
        releaseProcessingRoot
      ];
      Unit = "prism-release-promoter.service";
    };
  };

  # The timer covers events missed while the container or path unit was down.
  systemd.timers.prism-release-promoter = {
    description = "Periodic Prism release promotion scan";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitInactiveSec = "5m";
      Unit = "prism-release-promoter.service";
      RandomizedDelaySec = "30s";
    };
  };

  systemd.services.prism-release-promoter = {
    description = "Validate and publish completed Prism releases";
    after = [ "local-fs.target" ];
    serviceConfig = {
      User = "prism";
      Group = "prism";
      SupplementaryGroups = [ "prism-release-upload" ];
      Type = "oneshot";
      ExecStart = "${releasePromoter}/bin/prism-release-promote-ready";
      WorkingDirectory = "${prism-django}/share/prism-django";
      Environment = releaseEnvironment ++ [
        "DEBUG=false"
        "DISABLE_REDIS=true"
        # Django settings require a SECRET_KEY even though the isolated
        # promoter does not create or redeem download capabilities.
        "SECRET_KEY=prism-release-promoter-non-production-key"
        "USE_POSTGRES=false"
      ];
      UMask = "0027";

      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateNetwork = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      LockPersonality = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      ReadWritePaths = [ releaseRoot ];
    };
  };

  systemd.services.prism-django = {
    description = "Prism Django Application (Uvicorn)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "postgresql.service"
      "redis-prism.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "postgresql.service"
      "redis-prism.service"
    ];

    # Run migrations and collect static files before accepting traffic.
    preStart = ''
      echo "Running database migrations..."
      ${prism-django}/bin/prism-migrate

      echo "Collecting static files..."
      ${prism-django}/bin/prism-collectstatic
    '';

    serviceConfig = {
      User = "prism";
      Group = "prism";
      Type = "simple";
      WorkingDirectory = "${prism-django}/share/prism-django";
      ExecStart = "${prism-django}/bin/prism-uvicorn";
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

      Environment = [
        "DEBUG=false"
        "ALLOWED_HOSTS=prism.gravemind.sh,.gravemind.sh,prism.midship.local,midship.local,localhost,127.0.0.1,10.1.1.*"
        "USE_POSTGRES=true"
        "POSTGRES_DB=prism"
        "POSTGRES_HOST=localhost"
        "POSTGRES_PORT=5432"
        "REDIS_URL=unix:///run/redis-prism/redis.sock?db=0"
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
        "WEB_CONCURRENCY=8"
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
      ]
      ++ releaseEnvironment;

      EnvironmentFile = config.sops.secrets.prism-env.path;
      Restart = "always";
      RestartSec = 10;

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

      ReadWritePaths = [ stateDir ];
      ReadOnlyPaths = [ releaseRoot ];
    };
  };

  systemd.services.prism-celery-worker = {
    description = "Prism Celery Worker (Background Tasks)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "postgresql.service"
      "redis-prism.service"
      "prism-django.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "postgresql.service"
      "redis-prism.service"
    ];

    serviceConfig = {
      User = "prism";
      Group = "prism";
      Type = "simple";
      WorkingDirectory = "${prism-django}/share/prism-django";
      ExecStart = "${prism-django}/bin/prism-celery-worker --loglevel=info --pool=threads --concurrency=12";

      Environment = [
        "DEBUG=false"
        "ALLOWED_HOSTS=prism.gravemind.sh,.gravemind.sh,prism.midship.local,midship.local,localhost,127.0.0.1,10.1.1.*"
        "USE_POSTGRES=true"
        "POSTGRES_DB=prism"
        "POSTGRES_HOST=localhost"
        "POSTGRES_PORT=5432"
        "REDIS_URL=unix:///run/redis-prism/redis.sock?db=0"
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
        "CELERY_WORKER_PREFETCH_MULTIPLIER=1"
      ]
      ++ releaseEnvironment;
      EnvironmentFile = config.sops.secrets.prism-env.path;

      Restart = "always";
      RestartSec = 10;

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

      ReadWritePaths = [ stateDir ];
      ReadOnlyPaths = [ releaseRoot ];
    };
  };

  systemd.services.prism-celery-beat = {
    description = "Prism Celery Beat (Task Scheduler)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "postgresql.service"
      "redis-prism.service"
      "prism-django.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "postgresql.service"
      "redis-prism.service"
    ];

    serviceConfig = {
      User = "prism";
      Group = "prism";
      Type = "simple";
      WorkingDirectory = stateDir;
      ExecStart = "${prism-django}/bin/prism-celery-beat --loglevel=info --schedule=${stateDir}/celerybeat-schedule";

      Environment = [
        "DEBUG=false"
        "ALLOWED_HOSTS=prism.gravemind.sh,.gravemind.sh,prism.midship.local,midship.local,localhost,127.0.0.1,10.1.1.*"
        "USE_POSTGRES=true"
        "POSTGRES_DB=prism"
        "POSTGRES_HOST=localhost"
        "POSTGRES_PORT=5432"
        "REDIS_URL=unix:///run/redis-prism/redis.sock?db=0"
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
      ]
      ++ releaseEnvironment;
      EnvironmentFile = config.sops.secrets.prism-env.path;

      Restart = "always";
      RestartSec = 10;

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

      ReadWritePaths = [ stateDir ];
      ReadOnlyPaths = [ releaseRoot ];
    };
  };
}
