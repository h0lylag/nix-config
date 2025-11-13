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
    ];
    wants = [ "network-online.target" ];
    requires = [ "postgresql.service" ];
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

}
