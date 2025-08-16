{
  lib,
  pkgs,
}:

# DayZ server manager wrapper using steamcmd/steam-run.
# Proprietary game content is downloaded at runtime into a mutable directory.
# Usage:
#   dayz-server            # start
#   dayz-server --update   # update only
#   dayz-server --validate # validate only
# Env vars:
#   DAYZ_INSTALL_DIR  (default /var/lib/dayz)
#   DAYZ_STEAM_LOGIN  (REQUIRED - Steam username, DayZ needs authentication)
#   DAYZ_CPU_COUNT    (default 4)
#   DAYZ_GAME_PORT    (default 2302)
#   DAYZ_PROFILE_DIR  (default profiles)
#   DAYZ_CONFIG_FILE  (default serverDZ.cfg)
#   DAYZ_ENABLE_LOGS  (default 1)
#   DAYZ_SERVER_MODS  (semicolon list, relative to mods/)
#   DAYZ_MODS         (semicolon list, relative to mods/)

let
  steamcmd = pkgs.steamcmd;
  steamRun = pkgs.steam-run;
in
pkgs.stdenv.mkDerivation {
  pname = "dayz-server";
  version = "unstable-2025-08-15";
  src = null;
  dontUnpack = true;

  installPhase = ''
        runHook preInstall
        mkdir -p $out/bin

        cat > $out/bin/dayz-server <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail

    APP_ID="223350"
    INSTALL_DIR="''${DAYZ_INSTALL_DIR:-/var/lib/dayz}"
    STEAM_LOGIN="''${DAYZ_STEAM_LOGIN:-}"
    CPU_COUNT="''${DAYZ_CPU_COUNT:-4}"
    PORT="''${DAYZ_GAME_PORT:-2302}"
    PROFILE_DIR="''${DAYZ_PROFILE_DIR:-profiles}"
    CONFIG_FILE="''${DAYZ_CONFIG_FILE:-serverDZ.cfg}"
    MISSION="''${DAYZ_MISSION:-}"
    ENABLE_LOGS="''${DAYZ_ENABLE_LOGS:-1}"
    FILE_PATCHING="''${DAYZ_FILE_PATCHING:-0}"
    BATTLEYE_PATH="''${DAYZ_BATTLEYE_PATH:-}"
    LIMIT_FPS="''${DAYZ_LIMIT_FPS:-}"
    STORAGE_PATH="''${DAYZ_STORAGE_PATH:-}"

    STEAMCMD_PATH="@STEAMCMD@"
    STEAM_RUN_PATH="@STEAMRUN@"

    SERVER_MODS="''${DAYZ_SERVER_MODS:-}"
    MODS="''${DAYZ_MODS:-}"

    SERVER_MOD_PARAM="$SERVER_MODS"
    MOD_PARAM="$MODS"

    update() {
      echo "Updating DayZ server in $INSTALL_DIR ..."
      
      if [[ -z "$STEAM_LOGIN" ]]; then
        echo "Error: DAYZ_STEAM_LOGIN must be set to a valid Steam username (DayZ requires authentication)"
        exit 1
      fi
      
      mkdir -p "$INSTALL_DIR"
      local cmd=("$STEAMCMD_PATH" +force_install_dir "$INSTALL_DIR" +login "$STEAM_LOGIN" +app_update "$APP_ID")
      [[ "''${1-}" == validate ]] && cmd+=(validate)
      cmd+=(+quit)
      echo "> ''${cmd[*]}"
      "''${cmd[@]}"
    }

    start_server() {
      cd "$INSTALL_DIR"
      local cmd=("$STEAM_RUN_PATH" ./DayZServer)
      
      # Core required parameters
      cmd+=(-config="$CONFIG_FILE" -port="$PORT" -profiles="$PROFILE_DIR" -cpuCount="$CPU_COUNT")
      
      # Optional mission
      [[ -n "$MISSION" ]] && cmd+=(-mission="$MISSION")
      
      # Mod parameters
      [[ -n "$SERVER_MOD_PARAM" ]] && cmd+=(-serverMod="$SERVER_MOD_PARAM")
      [[ -n "$MOD_PARAM" ]] && cmd+=(-mod="$MOD_PARAM")
      
      # Logging flags
      if [[ "$ENABLE_LOGS" != 0 && "$ENABLE_LOGS" != false && "$ENABLE_LOGS" != False ]]; then
        cmd+=(-doLogs -adminLog -netLog -freezeCheck)
      fi
      
      # File patching
      [[ "$FILE_PATCHING" == 1 || "$FILE_PATCHING" == true ]] && cmd+=(-filePatching)
      
      # BattlEye path
      [[ -n "$BATTLEYE_PATH" ]] && cmd+=(-BEpath="$BATTLEYE_PATH")
      
      # FPS limit
      [[ -n "$LIMIT_FPS" ]] && cmd+=(-limitFPS="$LIMIT_FPS")
      
      # Storage path
      [[ -n "$STORAGE_PATH" ]] && cmd+=(-storage="$STORAGE_PATH")
      
      echo "Starting DayZ server..."
      echo "> ''${cmd[*]}"
      exec "''${cmd[@]}"
    }

    usage() {
      cat <<USAGE
    Usage: dayz-server [--update] [--validate] [--help]
      (no args)  start without updating
      --update   update via steamcmd (no start)
      --validate validate files only (no start)
      --help     show this help

    Environment variables:
      DAYZ_INSTALL_DIR   default: /var/lib/dayz
      DAYZ_STEAM_LOGIN   REQUIRED Steam username
      DAYZ_CPU_COUNT     default: 4
      DAYZ_GAME_PORT     default: 2302
      DAYZ_PROFILE_DIR   default: profiles
      DAYZ_CONFIG_FILE   default: serverDZ.cfg
      DAYZ_MISSION       optional mission name
      DAYZ_ENABLE_LOGS   default: 1
      DAYZ_FILE_PATCHING default: 0 (PBO only mode)
      DAYZ_BATTLEYE_PATH optional BattlEye path
      DAYZ_LIMIT_FPS     optional FPS limit (max 200)
      DAYZ_STORAGE_PATH  optional storage root folder
      DAYZ_SERVER_MODS   semicolon-separated server mods
      DAYZ_MODS          semicolon-separated client mods
    USAGE
    }

    case "''${1-}" in
      "") start_server ;;
      --update) update ;;
      --validate) update validate ;;
      --help|-h) usage ;;
      *) usage; exit 1 ;;
     esac
    EOF

        substituteInPlace $out/bin/dayz-server \
          --replace-fail @STEAMCMD@ ${steamcmd}/bin/steamcmd \
          --replace-fail @STEAMRUN@ ${steamRun}/bin/steam-run

        chmod +x $out/bin/dayz-server
        runHook postInstall
  '';

  meta = with lib; {
    description = "DayZ server manager wrapper (update/validate/start) using steamcmd (bash version)";
    platforms = platforms.linux;
    mainProgram = "dayz-server";
    license = licenses.unfreeRedistributable // {
      free = false;
    };
  };
}
