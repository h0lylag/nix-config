{
  lib,
  pkgs,
}:

# DayZ server manager wrapper using steamcmd/steam-run.
# Proprietary game content is downloaded at runtime into a mutable directory.
# Usage:
#   dayz-server            # start (no update)
#   dayz-server --update   # update then start
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
# Optional file: $DAYZ_INSTALL_DIR/modlist.txt with lines SERVER_MODS=... and MODS=...
# Only used if corresponding env vars unset.

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
    ENABLE_LOGS="''${DAYZ_ENABLE_LOGS:-1}"
    MODLIST_FILE="$INSTALL_DIR/modlist.txt"

    STEAMCMD_PATH="@STEAMCMD@"
    STEAM_RUN_PATH="@STEAMRUN@"

    SERVER_MODS="''${DAYZ_SERVER_MODS:-}"
    MODS="''${DAYZ_MODS:-}"

    if [[ -z "$SERVER_MODS$MODS" && -f "$MODLIST_FILE" ]]; then
      while IFS= read -r line; do
        case "$line" in
          SERVER_MODS\=*) SERVER_MODS="''${line#SERVER_MODS=}" ;;
          MODS\=*) MODS="''${line#MODS=}" ;;
        esac
      done < "$MODLIST_FILE"
    fi

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
      
      cmd+=(-config="$CONFIG_FILE" -port="$PORT" -profiles="$PROFILE_DIR" -cpuCount="$CPU_COUNT")
      
      [[ -n "$SERVER_MOD_PARAM" ]] && cmd+=(-serverMod="$SERVER_MOD_PARAM")
      [[ -n "$MOD_PARAM" ]] && cmd+=(-mod="$MOD_PARAM")
      
      if [[ "$ENABLE_LOGS" != 0 && "$ENABLE_LOGS" != false && "$ENABLE_LOGS" != False ]]; then
        cmd+=(-doLogs -adminLog -netLog -freezeCheck)
      fi
      
      echo "Starting DayZ server..."
      echo "> ''${cmd[*]}"
      exec "''${cmd[@]}"
    }

    usage() {
      cat <<USAGE
    Usage: dayz-server [--update] [--validate] [--help]
      (no args)  start without updating
      --update   update via steamcmd then start
      --validate validate only (no start)
      --help     show this help

    Environment variables:
      DAYZ_INSTALL_DIR   default: /var/lib/dayz
      DAYZ_STEAM_LOGIN   REQUIRED Steam username
      DAYZ_CPU_COUNT     default: 4
      DAYZ_GAME_PORT          default: 2302
      DAYZ_PROFILE_DIR   default: profiles
      DAYZ_CONFIG_FILE   default: serverDZ.cfg
      DAYZ_ENABLE_LOGS   default: 1
      DAYZ_SERVER_MODS   semicolon-separated server mods
      DAYZ_MODS          semicolon-separated client mods
    USAGE
    }

    case "''${1-}" in
      "") start_server ;;
      --update) update; start_server ;;
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
