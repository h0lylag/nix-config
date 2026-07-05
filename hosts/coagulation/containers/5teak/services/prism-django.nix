{
  config,
  pkgs,
  lib,
  ...
}:

let
  prism-django = pkgs.callPackage ../../../../../pkgs/prism-django/package.nix { };
  stateDir = "/var/lib/prism-django";
  prism-prod-manage = pkgs.writeShellScriptBin "prism-prod-manage" (
    builtins.concatStringsSep "\n" [
      "set -euo pipefail"
      ""
      "if [ \"$(id -u)\" -ne 0 ]; then"
      "  exec ${pkgs.sudo}/bin/sudo \"$0\" \"$@\""
      "fi"
      ""
      "exec ${pkgs.systemd}/bin/systemd-run --wait --pty --collect --uid=prism --gid=prism -p WorkingDirectory=${prism-django}/share/prism-django -p Environment=DEBUG=false -p Environment=USE_POSTGRES=true -p Environment=POSTGRES_DB=prism -p Environment=POSTGRES_HOST=localhost -p Environment=POSTGRES_PORT=5432 -p Environment=REDIS_URL=unix:///run/redis-prism/redis.sock?db=0 -p Environment=REDIS_CACHE_URL=redis://127.0.0.1:6379/1 -p Environment=REDIS_SESSION_URL=redis://127.0.0.1:6379/2 -p Environment=CELERY_BROKER_URL=redis://127.0.0.1:6379/0 -p Environment=EVEUNIVERSE_LOAD_STARGATES=true -p EnvironmentFile=${config.sops.secrets.prism-env.path} ${prism-django}/bin/prism-manage \"$@\""
    ]
  );
  staticDir = "${stateDir}/staticfiles";
  mediaDir = "${stateDir}/media";
in
{
  users.users.prism = {
    isSystemUser = true;
    group = "prism";
    description = "Prism Django service user";
    home = stateDir;
  };
  users.groups.prism = { };

  environment.systemPackages = [
    prism-prod-manage
  ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0751 prism prism - -"
    "d ${staticDir} 0755 prism prism - -"
    "d ${mediaDir} 0750 prism prism - -"
  ];

  sops.secrets.prism-env = {
    sopsFile = ../../../../../secrets/prism.env;
    format = "dotenv";
    owner = "prism";
    group = "prism";
  };

  systemd.services.prism-django = {
    description = "Prism Django Application (Gunicorn)";
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
      Type = "notify";
      WorkingDirectory = "${prism-django}/share/prism-django";
      ExecStart = "${prism-django}/bin/prism-gunicorn";

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
        "GUNICORN_WORKER_CLASS=gthread"
        "GUNICORN_THREADS=4"
        "GUNICORN_BIND=127.0.0.1:8000"
        "GUNICORN_TIMEOUT=60"
        "GUNICORN_KEEPALIVE=5"
      ];

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
      ];
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
      ];
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
    };
  };
}
