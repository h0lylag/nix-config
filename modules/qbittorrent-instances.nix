{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.services.qbittorrent-nox-instances;

  # Type definition for instance configuration
  instanceConfig = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable this qbittorrent-nox instance";
      };

      # Core configuration - leverage existing service options
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

      profileDir = mkOption {
        type = types.str;
        description = "Profile directory for this instance";
        example = "/var/lib/qbittorrent/auto";
      };

      # User and group - use defaults from main service
      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "User to run this instance as (null = use services.qbittorrent.user)";
      };

      group = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Group to run this instance as (null = use services.qbittorrent.group)";
      };

      # Additional options
      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ "--confirm-legal-notice" ];
        description = "Additional command line arguments for this instance";
        example = [ "--confirm-legal-notice" ];
      };

      # Service options
      restartSec = mkOption {
        type = types.str;
        default = "5s";
        description = "Restart delay for this instance";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Environment variables for this instance";
      };

      # Logging
      logFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Log file path (null = use journald only)";
      };
    };
  };

  # Generate systemd service for an instance
  mkService =
    name: instanceCfg:
    let
      # Use instance-specific values or fall back to main service defaults
      user = if instanceCfg.user != null then instanceCfg.user else config.services.qbittorrent.user;
      group = if instanceCfg.group != null then instanceCfg.group else config.services.qbittorrent.group;

      # Build command line arguments
      args = concatStringsSep " " (
        filter (x: x != "") [
          "--webui-port=${toString instanceCfg.webuiPort}"
          "--torrenting-port=${toString instanceCfg.torrentingPort}"
          "--profile=${instanceCfg.profileDir}"
        ]
        ++ instanceCfg.extraArgs
      );
    in
    {
      description = "qbittorrent-nox ${name} instance";
      documentation = [ "man:qbittorrent-nox(1)" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "nss-lookup.target"
      ];

      serviceConfig = {
        Type = "exec";
        User = user;
        Group = group;
        ExecStart = "${config.services.qbittorrent.package}/bin/qbittorrent-nox ${args}";
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
      user = if instanceCfg.user != null then instanceCfg.user else config.services.qbittorrent.user;
      group = if instanceCfg.group != null then instanceCfg.group else config.services.qbittorrent.group;
    in
    [
      "d ${instanceCfg.profileDir} 0750 ${user} ${group} -"
    ]
    ++ (optional (
      instanceCfg.logFile != null
    ) "d ${builtins.dirOf instanceCfg.logFile} 0750 ${user} ${group} -");

in
{
  options.services.qbittorrent-nox-instances = {
    enable = mkEnableOption "qbittorrent-nox multiple instances";

    instances = mkOption {
      type = types.attrsOf instanceConfig;
      default = { };
      description = "qbittorrent-nox instances to run";
      example = {
        auto = {
          webuiPort = 8040;
          torrentingPort = 58040;
          profileDir = "/var/lib/qbittorrent/auto";
        };
        movies = {
          webuiPort = 8041;
          torrentingPort = 58041;
          profileDir = "/var/lib/qbittorrent/movies";
        };
      };
    };
  };

  config = mkIf cfg.enable {
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
