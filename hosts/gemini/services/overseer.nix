{ config, pkgs, ... }:

{
  # Import overseer package
  environment.systemPackages = [ pkgs.overseer ];

  # Configure sops secrets for overseer
  sops.secrets.overseer-env = {
    sopsFile = ../secrets/overseer.env;
    format = "dotenv";
    owner = "overseer";
    group = "overseer";
  };

  # Create overseer user
  users.users.overseer = {
    isSystemUser = true;
    group = "overseer";
    home = "/var/lib/overseer";
    createHome = true;
    description = "Overseer Discord bot user";
  };

  users.groups.overseer = { };

  # Systemd service for overseer
  systemd.services.overseer = {
    description = "Overseer Discord Bot";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "postgresql.service"
    ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "simple";
      User = "overseer";
      Group = "overseer";
      WorkingDirectory = "/var/lib/overseer";

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/overseer" ];

      # Restart on failure
      Restart = "on-failure";
      RestartSec = "10s";

      # Load environment from sops-encrypted file
      EnvironmentFile = config.sops.secrets.overseer-env.path;
    };

    # Set up environment variables
    environment = {
      # Directory configuration
      OVERSEER_ROOT_DIR = "/var/lib/overseer";
      OVERSEER_SDE_DIR = "/var/lib/overseer/sde_data";
      LOG_DIR = "/var/lib/overseer/logs";

      # Database configuration (non-secret parts)
      DB_TYPE = "postgresql";
      DB_HOST = "localhost";
      DB_PORT = "5432";
      DB_DATABASE = "overseer";
      DB_USER = "overseer";
      OVERSEER_SDE_DB_NAME = "eve_sde";

      # Bot configuration
      BOT_PREFIX = "/";
      USE_GLOBAL_COMMANDS = "true";
      LOGGING_LEVEL = "INFO";

      # Secrets are loaded from EnvironmentFile (overseer.env via sops)
      # OVERSEER_BOT_TOKEN and OVERSEER_DB_PASSWORD come from that file
    };

    script = ''
      # OVERSEER_BOT_TOKEN and OVERSEER_DB_PASSWORD are loaded from EnvironmentFile
      # Config.py expects these namespaced variables
      exec ${pkgs.overseer}/bin/overseer
    '';
  };

  # Create necessary directories with proper permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/overseer 0750 overseer overseer -"
    "d /var/lib/overseer/logs 0750 overseer overseer -"
    "d /var/lib/overseer/sde_data 0750 overseer overseer -"
  ];
}
