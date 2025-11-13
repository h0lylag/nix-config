{
  config,
  pkgs,
  lib,
  ...
}:

let
  prism-django = pkgs.callPackage ../../../pkgs/prism-django/default.nix { };
  stateDir = "/var/lib/prism-django";
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

  # Ensure state directories exist with correct ownership
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 prism prism - -"
    "d ${staticDir} 0755 prism prism - -" # Static files need to be readable by nginx
    "d ${mediaDir} 0750 prism prism - -"
  ];

  # Secrets for sensitive configuration
  # Uses /home/chris/.nixos-config/secrets/prism.env
  # Required: SECRET_KEY, POSTGRES_PASSWORD
  # Optional: EMAIL_HOST_USER, EMAIL_HOST_PASSWORD
  sops.secrets.prism-env = {
    sopsFile = ../../../secrets/prism.env;
    format = "dotenv";
    owner = "prism";
    group = "prism";
  };

  systemd.services.prism-django = {
    description = "Prism Django Application (Gunicorn)";
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
    wantedBy = [ "multi-user.target" ];

    # Run migrations and collect static files before starting
    # These run as the service user (prism) defined in serviceConfig.User
    preStart = ''
      echo "Running database migrations..."
      ${prism-django}/bin/prism-migrate

      echo "Collecting static files..."
      ${prism-django}/bin/prism-collectstatic
    '';

    serviceConfig = {
      # Set user/group first so preStart inherits them
      User = "prism";
      Group = "prism";
      Type = "notify"; # Gunicorn supports systemd notify
      WorkingDirectory = "${prism-django}/share/prism-django";
      ExecStart = "${prism-django}/bin/prism-gunicorn";

      # Base environment configuration
      Environment = [
        # Django settings
        "DEBUG=false"
        "ALLOWED_HOSTS=prism.gravemind.sh,.gravemind.sh,prism.midship.local,midship.local,localhost,127.0.0.1,10.1.1.*"

        # PostgreSQL configuration
        "USE_POSTGRES=true"
        "POSTGRES_DB=prism"
        # POSTGRES_USER and POSTGRES_PASSWORD come from secrets file
        "POSTGRES_HOST=localhost"
        "POSTGRES_PORT=5432"

        # Redis configuration
        "REDIS_URL=unix:///run/redis-prism/redis.sock?db=0"
        # Celery doesn't support Unix sockets - use TCP
        "CELERY_BROKER_URL=redis://127.0.0.1:6379/0"

        # Paths for static/media files (writable state directory)
        "STATIC_ROOT=${staticDir}"
        "MEDIA_ROOT=${mediaDir}"

        # Email configuration
        # EMAIL_HOST_USER and EMAIL_HOST_PASSWORD come from secrets file
        "EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend"
        "EMAIL_HOST=smtp.gmail.com"
        "EMAIL_PORT=587"
        "EMAIL_USE_TLS=true"
        "DEFAULT_FROM_EMAIL=noreply@prism.midship.local"
        "SITE_NAME=Prism"

        # Gunicorn configuration
        "GUNICORN_WORKERS=4"
        "GUNICORN_BIND=127.0.0.1:8000"
        "GUNICORN_TIMEOUT=60"
      ];

      # Load secrets from sops-nix (SECRET_KEY, POSTGRES_PASSWORD, etc.)
      EnvironmentFile = config.sops.secrets.prism-env.path;

      # Service behavior
      Restart = "always";
      RestartSec = 10;

      # Systemd hardening
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

      # Allow writes to state directory
      ReadWritePaths = [ stateDir ];
    };
  };

  # Celery worker service for background tasks
  systemd.services.prism-celery-worker = {
    description = "Prism Celery Worker (Background Tasks)";
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
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "prism";
      Group = "prism";
      Type = "simple";
      WorkingDirectory = "${prism-django}/share/prism-django";

      # Run celery worker with concurrency
      ExecStart = "${prism-django}/bin/prism-celery-worker --loglevel=info --concurrency=4";

      # Base environment configuration (same as main service)
      Environment = [
        "DEBUG=false"
        "ALLOWED_HOSTS=prism.gravemind.sh,.gravemind.sh,prism.midship.local,midship.local,localhost,127.0.0.1,10.1.1.*"
        "USE_POSTGRES=true"
        "POSTGRES_DB=prism"
        "POSTGRES_HOST=localhost"
        "POSTGRES_PORT=5432"
        "REDIS_URL=unix:///run/redis-prism/redis.sock?db=0"
        # Celery doesn't support Unix sockets - use TCP
        "CELERY_BROKER_URL=redis://127.0.0.1:6379/0"
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

      # Systemd hardening (same as main service)
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

  # Celery beat service for scheduled tasks
  systemd.services.prism-celery-beat = {
    description = "Prism Celery Beat (Task Scheduler)";
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
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "prism";
      Group = "prism";
      Type = "simple";
      WorkingDirectory = stateDir; # Use writable state dir for schedule file

      # Run celery beat scheduler with schedule file in state directory
      ExecStart = "${prism-django}/bin/prism-celery-beat --loglevel=info --schedule=${stateDir}/celerybeat-schedule";

      # Base environment configuration (same as main service)
      Environment = [
        "DEBUG=false"
        "ALLOWED_HOSTS=prism.gravemind.sh,.gravemind.sh,prism.midship.local,midship.local,localhost,127.0.0.1,10.1.1.*"
        "USE_POSTGRES=true"
        "POSTGRES_DB=prism"
        "POSTGRES_HOST=localhost"
        "POSTGRES_PORT=5432"
        "REDIS_URL=unix:///run/redis-prism/redis.sock?db=0"
        # Celery doesn't support Unix sockets - use TCP
        "CELERY_BROKER_URL=redis://127.0.0.1:6379/0"
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

      # Systemd hardening (same as main service)
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

  # Flower service for Celery monitoring dashboard
  systemd.services.prism-flower = {
    description = "Prism Flower (Celery Monitoring Dashboard)";
    after = [
      "network-online.target"
      "redis-prism.service"
      "prism-celery-worker.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "redis-prism.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "prism";
      Group = "prism";
      Type = "simple";
      WorkingDirectory = stateDir; # Use writable state dir for flower.db

      # Run Flower with production settings
      # --port=5555 (default, localhost only)
      # --address=127.0.0.1 (bind to localhost, use SSH tunnel for remote access)
      # --persistent=True (enable task history storage)
      # --db (SQLite database for Flower state)
      # --max_tasks=10000 (keep last 10k tasks in memory)
      ExecStart = "${prism-django}/bin/prism-flower --port=5555 --address=127.0.0.1 --persistent=True --db=${stateDir}/flower.db --max_tasks=10000";

      # Base environment configuration (needs CELERY_BROKER_URL)
      Environment = [
        "DEBUG=false"
        # Celery broker URL for Flower to monitor
        "CELERY_BROKER_URL=redis://127.0.0.1:6379/0"
        # Django database connection (for task results)
        "USE_POSTGRES=true"
        "POSTGRES_DB=prism"
        "POSTGRES_HOST=localhost"
        "POSTGRES_PORT=5432"
      ];
      EnvironmentFile = config.sops.secrets.prism-env.path;

      Restart = "always";
      RestartSec = 10;

      # Systemd hardening
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

      # Allow writes to state directory (for flower.db)
      ReadWritePaths = [ stateDir ];
    };
  };

}
