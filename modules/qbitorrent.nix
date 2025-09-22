{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.services.qbittorrent-nox;

  # Type definitions for better validation
  instanceConfig = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable this qBittorrent-nox instance";
      };

      # Core configuration options
      webuiPort = mkOption {
        type = types.port;
        description = "WebUI port for this instance";
        example = 8080;
      };

      torrentingPort = mkOption {
        type = types.port;
        description = "Torrenting port for this instance";
        example = 6881;
      };

      profile = mkOption {
        type = types.str;
        description = "Profile directory name for this instance";
        example = "main";
      };

      # User and group options
      user = mkOption {
        type = types.str;
        default = "qbittorrent";
        description = "User to run qBittorrent-nox as";
      };

      group = mkOption {
        type = types.str;
        default = "qbittorrent";
        description = "Group to run qBittorrent-nox as";
      };

      # Directory options
      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/qbittorrent";
        description = "Base directory for qBittorrent data";
      };

      savePath = mkOption {
        type = types.str;
        description = "Default save path for torrents";
        example = "/var/lib/qbittorrent/downloads";
      };

      incompletePath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path for incomplete downloads (null = use savePath)";
      };

      watchPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path for watched torrent files (null = disabled)";
      };

      # Torrent options
      addStopped = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Add torrents as stopped (true) or running (false)";
      };

      skipHashCheck = mkOption {
        type = types.bool;
        default = false;
        description = "Skip hash check when adding torrents";
      };

      category = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Default category for new torrents";
      };

      sequential = mkOption {
        type = types.bool;
        default = false;
        description = "Download files in sequential order";
      };

      firstAndLast = mkOption {
        type = types.bool;
        default = false;
        description = "Download first and last pieces first";
      };

      skipDialog = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Skip the 'Add New Torrent' dialog";
      };

      # Advanced options
      relativeFastresume = mkOption {
        type = types.bool;
        default = false;
        description = "Make fastresume file paths relative to profile directory";
      };

      daemon = mkOption {
        type = types.bool;
        default = true;
        description = "Run in daemon mode (background)";
      };

      # Service options
      restartSec = mkOption {
        type = types.str;
        default = "5s";
        description = "Restart delay for the service";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Environment variables for the service";
      };

      # Logging options
      logFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Log file path (null = use journald only)";
      };

      # Additional command line arguments
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Additional command line arguments";
      };
    };
  };

  # Generate systemd service for an instance
  mkService =
    name: instanceCfg:
    let
      profileDir = "${instanceCfg.dataDir}/${instanceCfg.profile}";
      savePath = if instanceCfg.savePath != null then instanceCfg.savePath else "${profileDir}/downloads";
      incompletePath =
        if instanceCfg.incompletePath != null then
          instanceCfg.incompletePath
        else
          "${profileDir}/incomplete";
      watchPath =
        if instanceCfg.watchPath != null then instanceCfg.watchPath else "${profileDir}/watched";

      # Build command line arguments
      args = concatStringsSep " " (
        filter (x: x != "") [
          "--webui-port=${toString instanceCfg.webuiPort}"
          "--torrenting-port=${toString instanceCfg.torrentingPort}"
          "--profile=${profileDir}"
          "--save-path=${savePath}"
          (optionalString instanceCfg.daemon "--daemon")
          (optionalString instanceCfg.skipHashCheck "--skip-hash-check")
          (optionalString instanceCfg.sequential "--sequential")
          (optionalString instanceCfg.firstAndLast "--first-and-last")
          (optionalString instanceCfg.relativeFastresume "--relative-fastresume")
          (optionalString (instanceCfg.addStopped != null)
            "--add-stopped=${if instanceCfg.addStopped then "true" else "false"}"
          )
          (optionalString (instanceCfg.skipDialog != null)
            "--skip-dialog=${if instanceCfg.skipDialog then "true" else "false"}"
          )
          (optionalString (instanceCfg.category != null) "--category=${instanceCfg.category}")
        ]
        ++ instanceCfg.extraArgs
      );
    in
    {
      description = "qBittorrent-nox ${name} service";
      documentation = [ "man:qbittorrent-nox(1)" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "nss-lookup.target"
      ];

      serviceConfig = {
        Type = "exec";
        User = instanceCfg.user;
        Group = instanceCfg.group;
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox ${args}";
        Restart = "always";
        RestartSec = instanceCfg.restartSec;
        Environment = mapAttrsToList (name: value: "${name}=${value}") instanceCfg.environment;
      }
      // (
        if instanceCfg.logFile != null then
          {
            StandardOutput = "append:${instanceCfg.logFile}";
            StandardError = "inherit";
          }
        else
          { }
      );

      wantedBy = [ "multi-user.target" ];
    };

  # Generate tmpfiles rules for an instance
  mkTmpfiles =
    name: instanceCfg:
    let
      profileDir = "${instanceCfg.dataDir}/${instanceCfg.profile}";
      savePath = if instanceCfg.savePath != null then instanceCfg.savePath else "${profileDir}/downloads";
      incompletePath =
        if instanceCfg.incompletePath != null then
          instanceCfg.incompletePath
        else
          "${profileDir}/incomplete";
      watchPath =
        if instanceCfg.watchPath != null then instanceCfg.watchPath else "${profileDir}/watched";
    in
    [
      "d ${profileDir} 0750 ${instanceCfg.user} ${instanceCfg.group} -"
      "d ${savePath} 0770 ${instanceCfg.user} ${instanceCfg.group} -"
      "d ${incompletePath} 0770 ${instanceCfg.user} ${instanceCfg.group} -"
    ]
    ++ (optional (watchPath != null) "d ${watchPath} 0770 ${instanceCfg.user} ${instanceCfg.group} -")
    ++ (optional (
      instanceCfg.logFile != null
    ) "d ${builtins.dirOf instanceCfg.logFile} 0750 ${instanceCfg.user} ${instanceCfg.group} -");

in
{
  options.services.qbittorrent-nox = {
    enable = mkEnableOption "qBittorrent-nox service";

    package = mkOption {
      type = types.package;
      default = pkgs.qbittorrent-nox;
      description = "qBittorrent-nox package to use";
    };

    instances = mkOption {
      type = types.attrsOf instanceConfig;
      default = { };
      description = "qBittorrent-nox instances to run";
      example = {
        main = {
          webuiPort = 8080;
          torrentingPort = 6881;
          profile = "main";
          savePath = "/var/lib/qbittorrent/downloads";
        };
        movies = {
          webuiPort = 8081;
          torrentingPort = 6882;
          profile = "movies";
          savePath = "/var/lib/qbittorrent/movies";
          category = "movies";
        };
      };
    };

    # Global options that apply to all instances
    global = {
      user = mkOption {
        type = types.str;
        default = "qbittorrent";
        description = "Default user for qBittorrent-nox instances";
      };

      group = mkOption {
        type = types.str;
        default = "qbittorrent";
        description = "Default group for qBittorrent-nox instances";
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/qbittorrent";
        description = "Default base directory for qBittorrent data";
      };
    };
  };

  config = mkIf cfg.enable {
    # Add qBittorrent-nox to system packages
    environment.systemPackages = [ cfg.package ];

    # Note: Users and groups must be created separately in the configuration
    # The module assumes they already exist

    # Generate tmpfiles rules for all instances
    systemd.tmpfiles.rules = concatLists (
      mapAttrsToList (
        name: instanceCfg: if instanceCfg.enable then mkTmpfiles name instanceCfg else [ ]
      ) cfg.instances
    );

    # Generate systemd services for all instances
    systemd.services = listToAttrs (
      mapAttrsToList (
        name: instanceCfg:
        if instanceCfg.enable then
          nameValuePair "qbittorrent-${name}" (mkService name instanceCfg)
        else
          nameValuePair "qbittorrent-${name}" { }
      ) cfg.instances
    );

    # Open firewall ports for all enabled instances
    networking.firewall.allowedTCPPorts = concatLists (
      mapAttrsToList (
        name: instanceCfg:
        if instanceCfg.enable then
          [
            instanceCfg.webuiPort
            instanceCfg.torrentingPort
          ]
        else
          [ ]
      ) cfg.instances
    );

    # Allow UDP for torrenting ports
    networking.firewall.allowedUDPPorts = concatLists (
      mapAttrsToList (
        name: instanceCfg: if instanceCfg.enable then [ instanceCfg.torrentingPort ] else [ ]
      ) cfg.instances
    );
  };
}
