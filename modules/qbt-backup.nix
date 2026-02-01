{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.qbt-backup;
  qbt-backup-pkg = pkgs.callPackage ../pkgs/qbt-backup/default.nix { };
in
{
  options.services.qbt-backup = {
    enable = lib.mkEnableOption "qBittorrent backup service";

    package = lib.mkOption {
      type = lib.types.package;
      default = qbt-backup-pkg;
      description = "The qbt-backup package to use.";
    };

    sourceRoot = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/qbittorrent/";
      description = "Directory containing qBittorrent instances.";
    };

    backupRoot = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/hdd-pool/main/Backups/qBittorrent/";
      description = "Directory to store backups.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/hdd-pool";
      description = "Mount point to check before running backups (safety check).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "User to run the backup service as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Group to run the backup service as.";
    };

    compressionLevel = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = "Gzip compression level (1-9).";
    };

    retention = {
      hourly = {
        enable = lib.mkEnableOption "hourly backups" // {
          default = true;
        };
        keep = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "Number of hourly backups to keep.";
        };
      };
      daily = {
        enable = lib.mkEnableOption "daily backups" // {
          default = true;
        };
        keep = lib.mkOption {
          type = lib.types.int;
          default = 7;
          description = "Number of daily backups to keep.";
        };
      };
      weekly = {
        enable = lib.mkEnableOption "weekly backups" // {
          default = true;
        };
        keep = lib.mkOption {
          type = lib.types.int;
          default = 4;
          description = "Number of weekly backups to keep.";
        };
      };
      monthly = {
        enable = lib.mkEnableOption "monthly backups" // {
          default = true;
        };
        keep = lib.mkOption {
          type = lib.types.int;
          default = 6;
          description = "Number of monthly backups to keep.";
        };
      };
    };

    startAt = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "Systemd calendar event for the backup schedule.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.qbt-backup = {
      description = "qBittorrent Backup Service";
      wantedBy = [ "multi-user.target" ];
      startAt = cfg.startAt;

      environment = {
        QBT_SOURCE_ROOT = cfg.sourceRoot;
        QBT_BACKUP_ROOT = cfg.backupRoot;
        QBT_MOUNT_POINT = cfg.mountPoint;
        QBT_COMPRESSION_LEVEL = toString cfg.compressionLevel;

        QBT_ENABLE_HOURLY = if cfg.retention.hourly.enable then "true" else "false";
        QBT_KEEP_HOURLY = toString cfg.retention.hourly.keep;

        QBT_ENABLE_DAILY = if cfg.retention.daily.enable then "true" else "false";
        QBT_KEEP_DAILY = toString cfg.retention.daily.keep;

        QBT_ENABLE_WEEKLY = if cfg.retention.weekly.enable then "true" else "false";
        QBT_KEEP_WEEKLY = toString cfg.retention.weekly.keep;

        QBT_ENABLE_MONTHLY = if cfg.retention.monthly.enable then "true" else "false";
        QBT_KEEP_MONTHLY = toString cfg.retention.monthly.keep;
      };

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/qbt-backup";
      };
    };
  };
}
