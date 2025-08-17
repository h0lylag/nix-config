{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.dayz-server;
  dayz-server = pkgs.callPackage ../pkgs/dayz-server/default.nix { };
in
{
  options.services.dayz-server = {
    enable = mkEnableOption "DayZ dedicated server";

    user = mkOption {
      type = types.str;
      default = "dayz-server";
      description = "User to run the DayZ server as";
    };

    group = mkOption {
      type = types.str;
      default = "dayz-server";
      description = "Group to run the DayZ server as";
    };

    installDir = mkOption {
      type = types.path;
      default = "/home/dayz";
      description = "Directory where DayZ server files are installed";
    };

    steamLogin = mkOption {
      type = types.str;
      description = "Steam username for downloading server files (required)";
    };

    port = mkOption {
      type = types.port;
      default = 2302;
      description = "Game port for the DayZ server";
    };

    cpuCount = mkOption {
      type = types.ints.positive;
      default = 4;
      description = "Number of CPU cores to use";
    };

    profileDir = mkOption {
      type = types.str;
      default = "profiles";
      description = "Profile directory relative to install directory";
    };

    modDir = mkOption {
      type = types.str;
      default = "mods";
      description = "Mods directory relative to install directory";
    };

    configFile = mkOption {
      type = types.str;
      default = "serverDZ.cfg";
      description = "Server configuration file name";
    };

    mission = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Mission to use for the server";
      example = "dayzOffline.chernarusplus";
    };

    enableLogs = mkOption {
      type = types.bool;
      default = true;
      description = "Enable server logging (-doLogs -adminLog -netLog -freezeCheck)";
    };

    filePatching = mkOption {
      type = types.bool;
      default = false;
      description = "Ensures that only PBOs are loaded and NO unpacked data";
    };

    battleEyePath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Custom path to BattlEye files";
      example = "battleye";
    };

    limitFPS = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = "Limits server FPS to specified value (max 200)";
      example = 60;
    };

    storagePath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Custom root folder for storage location";
      example = "storage";
    };

    serverMods = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of server-only mods (relative to mod directory)";
      example = [
        "@DayZ Editor Loader"
        "@VPPAdminTools"
      ];
    };

    mods = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of client mods (relative to mod directory)";
      example = [
        "@CF"
        "@BaseBuildingPlus"
        "@Code Lock"
      ];
    };

    autoUpdate = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically update server files on startup";
    };

    restartInterval = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Systemd calendar interval for automatic server restarts";
      example = "daily";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports for the DayZ server";
    };

    extraEnvironment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables to pass to the server";
    };
  };

  config = mkIf cfg.enable {

    # Create user and group only if using the default dayz-server user
    users.users = mkIf (cfg.user == "dayz-server") {
      ${cfg.user} = {
        isNormalUser = true;
        group = cfg.group;
        createHome = true;
        description = "DayZ server user";
      };
    };

    users.groups = mkIf (cfg.group == "dayz-server") {
      ${cfg.group} = { };
    };

    # Ensure install directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.installDir} 0755 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.installDir}/profiles 0755 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.installDir}/${cfg.modDir} 0755 ${cfg.user} ${cfg.group} - -"
    ];

    # Main systemd service
    systemd.services.dayz-server = {
      description = "DayZ Dedicated Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        DAYZ_INSTALL_DIR = cfg.installDir;
        DAYZ_STEAM_LOGIN = cfg.steamLogin;
        DAYZ_GAME_PORT = toString cfg.port;
        DAYZ_CPU_COUNT = toString cfg.cpuCount;
        DAYZ_PROFILE_DIR = cfg.profileDir;
        DAYZ_MOD_DIR = cfg.modDir;
        DAYZ_CONFIG_FILE = cfg.configFile;
        DAYZ_MISSION = mkIf (cfg.mission != null) cfg.mission;
        DAYZ_ENABLE_LOGS = if cfg.enableLogs then "1" else "0";
        DAYZ_FILE_PATCHING = if cfg.filePatching then "1" else "0";
        DAYZ_BATTLEYE_PATH = mkIf (cfg.battleEyePath != null) cfg.battleEyePath;
        DAYZ_LIMIT_FPS = mkIf (cfg.limitFPS != null) (toString cfg.limitFPS);
        DAYZ_STORAGE_PATH = mkIf (cfg.storagePath != null) cfg.storagePath;
        DAYZ_SERVER_MODS = concatStringsSep ";" cfg.serverMods;
        DAYZ_MODS = concatStringsSep ";" cfg.mods;
      }
      // cfg.extraEnvironment;

      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.installDir;
        Restart = "always";
        RestartSec = "15s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.installDir ];

        # Resource limits
        LimitNOFILE = "100000";

        # The actual server command
        ExecStart =
          if cfg.autoUpdate then
            "${pkgs.writeShellScript "dayz-server-with-update" ''
              set -euo pipefail
              ${dayz-server}/bin/dayz-server --update
              exec ${dayz-server}/bin/dayz-server
            ''}"
          else
            "${dayz-server}/bin/dayz-server";
      };
    };

    # Optional update service for manual server updates
    systemd.services.dayz-server-update = {
      description = "Update DayZ Server Files";

      environment = {
        DAYZ_INSTALL_DIR = cfg.installDir;
        DAYZ_STEAM_LOGIN = cfg.steamLogin;
      };

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.installDir;
        ExecStart = "${dayz-server}/bin/dayz-server --validate";
      };
    };

    # Optional restart timer
    systemd.timers.dayz-server-restart = mkIf (cfg.restartInterval != null) {
      description = "Restart DayZ Server Timer";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.restartInterval;
        Persistent = true;
      };
    };

    systemd.services.dayz-server-restart = mkIf (cfg.restartInterval != null) {
      description = "Restart DayZ Server";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart dayz-server.service";
      };
    };

    # Firewall configuration - dayz only uses UDP port
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [
        cfg.port
        2303 # DayZ Reserved
        2304 # DayZ BattlEye
        2305 # DayZ Default RCON
        2306 # DayZ Reserved
        27016 # Steam query
      ];
      allowedUDPPorts = [
        cfg.port
        2303 # DayZ Reserved
        2304 # DayZ BattlEye
        2305 # DayZ Default RCON
        2306 # DayZ Reserved
        27016 # Steam query
      ];
    };

    # Install the dayz-server package system-wide
    environment.systemPackages = [ dayz-server ];

    # Ensure steamcmd and steam-run are available
    programs.steam.enable = true;
  };
}
