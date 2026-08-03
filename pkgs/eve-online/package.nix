{
  coreutils,
  fetchurl,
  icoutils,
  lib,
  makeDesktopItem,
  proton-ge-bin,
  runCommand,
  symlinkJoin,
  umu-launcher,
  writeShellApplication,
}:

let
  pname = "eve-online";

  # Keep CCP's launcher available for installing, updating, and repairing the
  # client even though CMEL is the normal entry point.
  version = "1.15.4";

  installer = fetchurl {
    url = "https://launcher.ccpgames.com/eve-online/release/win32/x64/eve-online-${version}+Setup.exe";
    name = "eve-online-${version}+Setup.exe";
    hash = "sha256-Y3P3fHfHZTLSjaYHzYrprXvFj0tyyniJJUxUSeWdRPk=";
  };

  umuEnvironment = ''
    # CMEL is the top-level Wine process. Clear any container re-entry state
    # inherited from an older shell environment.
    unset \
      PROTON_VERB \
      STEAM_COMPAT_LAUNCHER_SERVICE \
      UMU_CONTAINER_NSENTER \
      UMU_CONTAINER_NSENTER_CREATE \
      UMU_CONTAINER_NSENTER_REQUIRED

    export GAMEID=umu-default
    export STORE=none
    export PROTONPATH=${lib.escapeShellArg proton-ge-bin.steamcompattool}
    export PROTONFIXES_DISABLE=1
    export PROTON_USE_XALIA=0
    export WINEDLLOVERRIDES="winemenubuilder.exe=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
  '';

  # CCP embeds the launcher's 256px PNG as icon resource 19.
  launcherIcon = runCommand "${pname}-icon-${version}" { nativeBuildInputs = [ icoutils ]; } ''
    iconPath="$out/share/icons/hicolor/256x256/apps/${pname}.png"
    mkdir -p "$(dirname "$iconPath")"
    wrestool --extract --raw --type=3 --name=19 --output="$iconPath" ${lib.escapeShellArg installer}
  '';

  launcher = writeShellApplication {
    name = pname;
    runtimeInputs = [
      coreutils
      umu-launcher
    ];
    text = ''
      umask 077

      WINEPREFIX="''${EVE_WINEPREFIX:-$HOME/Games/eve-online}"
      WINEPREFIX="$(realpath -m -- "$WINEPREFIX")"
      export WINEPREFIX
      export STEAM_COMPAT_INSTALL_PATH="$WINEPREFIX"
      ${umuEnvironment}

      show_help() {
        cat <<'EOF'
      Usage: eve-online [--official | --installer | --help] [launcher arguments...]

        (default)    Run Windows CMEL inside the EVE Wine prefix
        --official   Run CCP's launcher for client updates and repairs
        --installer  Run the pinned CCP launcher installer
        --help       Show this help

      Environment:
        EVE_WINEPREFIX  Wine prefix (default: ~/Games/eve-online)
        EVE_CMEL_EXE    CMEL executable (default: <prefix>/drive_c/CMEL/eve-launcher.exe)

      Close CMEL and every EVE client before running --official or --installer.
      EOF
      }

      mkdir -p "$WINEPREFIX"

      discover_official_launcher() {
        local latest_versioned
        local version_candidates=()

        shopt -s nullglob
        version_candidates=(
          "$WINEPREFIX"/drive_c/users/steamuser/AppData/Local/eve-online/app-*/eve-online.exe
        )
        shopt -u nullglob

        if (( ''${#version_candidates[@]} == 0 )); then
          return 1
        fi

        latest_versioned="$(
          printf '%s\n' "''${version_candidates[@]}" \
            | sort --version-sort \
            | tail -n 1
        )"
        official_workdir="$(dirname "$latest_versioned")"
        official_exe="$(dirname "$official_workdir")/eve-online.exe"
        [[ -f "$official_exe" ]]
      }

      run_cmel() {
        local cmel_exe
        cmel_exe="''${EVE_CMEL_EXE:-$WINEPREFIX/drive_c/CMEL/eve-launcher.exe}"
        if ! cmel_exe="$(realpath -e -- "$cmel_exe" 2>/dev/null)" \
          || [[ ! -f "$cmel_exe" ]]; then
          printf 'Windows CMEL executable not found: %s\n' \
            "''${EVE_CMEL_EXE:-$WINEPREFIX/drive_c/CMEL/eve-launcher.exe}" >&2
          printf '%s\n' \
            'Copy eve-launcher.exe there or set EVE_CMEL_EXE to its absolute path.' >&2
          exit 1
        fi

        cd "$(dirname "$cmel_exe")"
        exec umu-run "$cmel_exe" "$@"
      }

      run_official_launcher() {
        if ! discover_official_launcher; then
          printf '%s\n' \
            'The CCP launcher is not installed in this prefix.' \
            'Run eve-online --installer first.' >&2
          exit 1
        fi

        cd "$official_workdir"
        exec umu-run "$official_exe" --product=eve-online "$@"
      }

      case "''${1:-}" in
        --help|-h)
          show_help
          ;;
        --installer)
          shift
          cd "$WINEPREFIX"
          exec umu-run ${lib.escapeShellArg installer} "$@"
          ;;
        --official)
          shift
          run_official_launcher "$@"
          ;;
        *)
          run_cmel "$@"
          ;;
      esac
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "EVE Online";
    genericName = "EVE Online Launcher";
    comment = "Run Windows CMEL and EVE Online through UMU/Proton";
    exec = "${launcher}/bin/${pname}";
    icon = pname;
    categories = [ "Game" ];
    startupNotify = true;
  };
in
symlinkJoin {
  inherit pname version;
  paths = [
    launcher
    launcherIcon
    desktopItem
  ];

  meta = {
    description = "Windows CMEL and EVE Online launcher for NixOS";
    homepage = "https://www.eveonline.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
