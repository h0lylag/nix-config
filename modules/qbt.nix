{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# qBittorrent-nox Service Module
#
# This module configures and manages multiple instances of qBittorrent-nox.
# It uses a "freeform" configuration approach via `serverConfig` to align with
# official NixOS module conventions, allowing direct mapping of Nix attributes
# to the INI-style `qBittorrent.conf`.
#
# Key Features:
# 1. Multi-instance support: Run multiple independent qBittorrent services.
# 2. Freeform Config: Use `serverConfig` to set any qBittorrent setting.
#    Example:
#      serverConfig = {
#        BitTorrent = { "Session\PeXEnabled" = false; };
#        Preferences = { "WebUI\AuthSubnetWhitelist" = "10.0.0.0/8"; };
#      };
# 3. Automatic User/Group Creation: Creates `qbittorrent` user/group if used.
# 4. Config Management:
#    - Seeding (default): Creates config only if missing (preserves WebUI changes).
#    - Overwrite: Enforces declarative config on every rebuild.
# 5. XDG Compliance & --profile:
#    This module uses the native `qbittorrent-nox --profile=<dir>` argument.
#    This ensures:
#    - Complete isolation between instances (no shared `~/.config`).
#    - Predictable paths: Configs are always at `<profile>/qBittorrent/config/`.
#    - Data locality: Torrents and data live within the profile directory structure.
# ==============================================================================

with lib;

let
  cfg = config.services.qbt;

  # ----------------------------------------------------------------------------
  # Helper Functions
  # ----------------------------------------------------------------------------

  # Format Nix values to INI-compatible strings
  formatValue =
    value:
    if isBool value then
      (if value then "true" else "false")
    else if isList value then
      concatStringsSep ", " (map toString value)
    else
      toString value;

  # Generate INI config content from attributes
  generateConfig =
    instanceCfg:
    let
      # Ensure explicit ports are merged into the freeform config
      baseConfig = instanceCfg.serverConfig;
      mergedConfig = baseConfig // {
        Preferences = (baseConfig.Preferences or { }) // {
          "WebUI\\Port" = baseConfig.Preferences."WebUI\\Port" or instanceCfg.webuiPort;
        };
        BitTorrent = (baseConfig.BitTorrent or { }) // {
          "Session\\Port" = baseConfig.BitTorrent."Session\\Port" or instanceCfg.torrentingPort;
        };
      };

      # Convert nested sets to [Section] key=value format
      configLines = concatStringsSep "\n\n" (
        mapAttrsToList (
          sectionName: sectionAttrs:
          let
            lines = mapAttrsToList (key: value: "${key}=${formatValue value}") (
              filterAttrs (_: v: v != null) sectionAttrs
            );
          in
          if lines == [ ] then "" else "[${sectionName}]\n" + concatStringsSep "\n" lines
        ) (filterAttrs (_: v: v != { }) mergedConfig)
      );
    in
    pkgs.writeText "qBittorrent.conf" configLines;

  # ----------------------------------------------------------------------------
  # Generators (Scripts, Services, Rules)
  # ----------------------------------------------------------------------------

  # Script to manage configuration file lifecycle (seed vs overwrite)
  mkConfigManager =
    name: instanceCfg:
    let
      profileDir = "${instanceCfg.dataDir}/${instanceCfg.profile}";
      configFile = generateConfig instanceCfg;
      configPath = "${profileDir}/qBittorrent/config/qBittorrent.conf";
    in
    pkgs.writeShellScript "qbittorrent-config-manager-${name}" ''
      set -e

      CONFIG_PATH="${configPath}"
      GENERATED_CONFIG="${configFile}"

      mkdir -p "$(dirname "$CONFIG_PATH")"

      if [ ! -f "$CONFIG_PATH" ]; then
        # Seed: Config missing, install generated one
        echo "Creating initial qBittorrent config for ${name}..."
        cp "$GENERATED_CONFIG" "$CONFIG_PATH"
        chown ${instanceCfg.user}:${instanceCfg.group} "$CONFIG_PATH"
        chmod 640 "$CONFIG_PATH"
      elif ${if instanceCfg.configManagement.overwriteOnRebuild then "true" else "false"}; then
        # Overwrite: Force replace existing config
        echo "Overwriting qBittorrent config for ${name}..."
        cp -f "$GENERATED_CONFIG" "$CONFIG_PATH"
        chown ${instanceCfg.user}:${instanceCfg.group} "$CONFIG_PATH"
        chmod 640 "$CONFIG_PATH"
      else
        # Safe: Do nothing if file exists
        echo "Checking qBittorrent config for ${name}..."
        if [ ! -s "$CONFIG_PATH" ]; then
           echo "Seeding qBittorrent config for ${name} (file was empty)..."
           cp "$GENERATED_CONFIG" "$CONFIG_PATH"
           chown ${instanceCfg.user}:${instanceCfg.group} "$CONFIG_PATH"
           chmod 640 "$CONFIG_PATH"
        fi
      fi
    '';

  # Create necessary directories with correct permissions via tmpfiles.d
  mkTmpfiles =
    name: instanceCfg:
    let
      profileDir = "${instanceCfg.dataDir}/${instanceCfg.profile}";
    in
    [
      "d ${instanceCfg.dataDir} 0755 ${instanceCfg.user} ${instanceCfg.group} -"
      "d ${profileDir} 0750 ${instanceCfg.user} ${instanceCfg.group} -"
      # qBittorrent-nox expects config in <profile>/qBittorrent/config/qBittorrent.conf
      "d ${profileDir}/qBittorrent 0750 ${instanceCfg.user} ${instanceCfg.group} -"
      "d ${profileDir}/qBittorrent/config 0750 ${instanceCfg.user} ${instanceCfg.group} -"
    ];

  # Define systemd service unit
  mkService =
    name: instanceCfg:
    let
      profileDir = "${instanceCfg.dataDir}/${instanceCfg.profile}";
      args = concatStringsSep " " (
        filter (x: x != "") [
          "--profile=${profileDir}"
          "--webui-port=${toString instanceCfg.webuiPort}"
        ]
        ++ instanceCfg.extraArgs
      );
    in
    {
      description = "qBittorrent ${name} service";
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
        # WorkingDirectory is required for correct file creation in relative paths
        WorkingDirectory = profileDir;
      };

      wantedBy = [ "multi-user.target" ];
    };

in
{
  # ----------------------------------------------------------------------------
  # Module Options
  # ----------------------------------------------------------------------------
  options.services.qbt = {
    enable = mkEnableOption "qBittorrent service";

    package = mkOption {
      type = types.package;
      default = pkgs.qbittorrent-nox;
      description = "qBittorrent-nox package to use";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall for WebUI and torrenting ports of enabled instances";
    };

    instances = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to enable this qBittorrent instance";
            };

            profile = mkOption {
              type = types.str;
              description = "Profile directory name (e.g. 'main')";
              example = "main";
            };

            # Identity
            user = mkOption {
              type = types.str;
              default = "qbittorrent";
              description = "User to run qBittorrent as";
            };

            group = mkOption {
              type = types.str;
              default = "qbittorrent";
              description = "Group to run qBittorrent as";
            };

            # Storage & Network
            dataDir = mkOption {
              type = types.str;
              default = "/var/lib/qbittorrent";
              description = "Base directory for qBittorrent data";
            };

            webuiPort = mkOption {
              type = types.port;
              default = 8080;
              description = "WebUI port (automatically opened if openFirewall is set)";
            };

            torrentingPort = mkOption {
              type = types.port;
              default = 6881;
              description = "BitTorrent port (automatically opened if openFirewall is set)";
            };

            # Configuration
            serverConfig = mkOption {
              type = types.attrsOf (types.attrsOf types.anything);
              default = { };
              description = ''
                Free-form settings mapped to the `qBittorrent.conf` file.
                Top-level keys are INI sections like `BitTorrent` or `Preferences`.
              '';
            };

            configManagement = mkOption {
              type = types.submodule {
                options = {
                  overwriteOnRebuild = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Overwrite config file on every rebuild (true) or seed it once (false)";
                  };

                  seedConfig = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Create initial config file if it doesn't exist";
                  };
                };
              };
              default = { };
              description = "Configuration file management options";
            };

            # Execution
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

            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Additional command line arguments";
            };
          };
        }
      );
      default = { };
      description = "qBittorrent instances to run";
    };
  };

  # ----------------------------------------------------------------------------
  # Implementation
  # ----------------------------------------------------------------------------
  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # 1. User & Group Creation (Foundational)
    users.users = mkIf (any (cfg: cfg.user == "qbittorrent") (attrValues cfg.instances)) {
      qbittorrent = {
        isSystemUser = true;
        group = "qbittorrent";
        description = "qBittorrent user";
      };
    };

    users.groups = mkIf (any (cfg: cfg.group == "qbittorrent") (attrValues cfg.instances)) {
      qbittorrent = { };
    };

    # 2. Networking (Firewall)
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall (
      concatLists (
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
      )
    );

    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall (
      concatLists (
        mapAttrsToList (
          name: instanceCfg: if instanceCfg.enable then [ instanceCfg.torrentingPort ] else [ ]
        ) cfg.instances
      )
    );

    # 3. Directory Structure (Tmpfiles)
    systemd.tmpfiles.rules = concatLists (
      mapAttrsToList (
        name: instanceCfg: if instanceCfg.enable then mkTmpfiles name instanceCfg else [ ]
      ) cfg.instances
    );

    # 4. Service Definitions
    systemd.services = listToAttrs (
      mapAttrsToList (
        name: instanceCfg:
        if instanceCfg.enable then
          nameValuePair "qbt-${name}" (
            (mkService name instanceCfg)
            // {
              # Inject config management before service start
              preStart = "${mkConfigManager name instanceCfg}";
            }
          )
        else
          nameValuePair "qbt-${name}" { }
      ) cfg.instances
    );
  };
}
