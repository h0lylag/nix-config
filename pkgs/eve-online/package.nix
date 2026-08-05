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
  # client. CMEL is provided as a separate command and desktop entry.
  version = "1.15.4";

  installer = fetchurl {
    url = "https://launcher.ccpgames.com/eve-online/release/win32/x64/eve-online-${version}+Setup.exe";
    name = "eve-online-${version}+Setup.exe";
    hash = "sha256-Y3P3fHfHZTLSjaYHzYrprXvFj0tyyniJJUxUSeWdRPk=";
  };

  cmelIconBase64 = builtins.toFile "cmel.png.base64" ''
    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
  '';

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

  # Exact 192px CMEL artwork from the Windows launcher's source tree.
  cmelIcon = runCommand "cmel-icon" { nativeBuildInputs = [ coreutils ]; } ''
    iconPath="$out/share/icons/hicolor/192x192/apps/cmel.png"
    mkdir -p "$(dirname "$iconPath")"
    base64 --decode ${cmelIconBase64} > "$iconPath"
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
      Usage: eve-online [--cmel | --install | --help] [launcher arguments...]

        (default)     Run CCP's official EVE Online launcher
        --cmel        Run Windows CMEL inside the EVE Wine prefix
        --install     Run the pinned CCP launcher installer
        --help        Show this help

      Environment:
        EVE_WINEPREFIX  Wine prefix (default: ~/Games/eve-online)
        EVE_CMEL_EXE    CMEL executable (default: <prefix>/drive_c/CMEL/eve-launcher.exe)

      Close CMEL, the official launcher, and every EVE client before running --install.
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
            'Run eve-online --install first.' >&2
          exit 1
        fi

        cd "$official_workdir"
        exec umu-run "$official_exe" --product=eve-online "$@"
      }

      case "''${1:-}" in
        --help|-h)
          show_help
          ;;
        --install)
          shift
          cd "$WINEPREFIX"
          exec umu-run ${lib.escapeShellArg installer} "$@"
          ;;
        --cmel)
          shift
          run_cmel "$@"
          ;;
        *)
          run_official_launcher "$@"
          ;;
      esac
    '';
  };

  cmelLauncher = writeShellApplication {
    name = "cmel";
    text = ''
      exec ${launcher}/bin/${pname} --cmel "$@"
    '';
  };

  officialDesktopItem = makeDesktopItem {
    name = pname;
    desktopName = "EVE Online";
    genericName = "EVE Online Launcher";
    comment = "EVE Online official launcher";
    exec = "${launcher}/bin/${pname}";
    icon = pname;
    categories = [ "Game" ];
    startupNotify = true;
  };

  cmelDesktopItem = makeDesktopItem {
    name = "cmel";
    desktopName = "Cormack's Modified EVE Launcher";
    genericName = "EVE Online Launcher";
    comment = "EVE Online CMEL launcher";
    exec = "${cmelLauncher}/bin/cmel";
    icon = "cmel";
    categories = [ "Game" ];
    startupNotify = true;
  };
in
symlinkJoin {
  inherit pname version;
  paths = [
    launcher
    cmelLauncher
    launcherIcon
    cmelIcon
    officialDesktopItem
    cmelDesktopItem
  ];

  meta = {
    description = "Official EVE Online launcher and Windows CMEL for NixOS";
    homepage = "https://www.eveonline.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
