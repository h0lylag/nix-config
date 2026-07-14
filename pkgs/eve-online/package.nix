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

  # To update this pin, download CCP's `eve-online-latest+Setup.exe`, read its
  # embedded ProductVersion and set `version` below. Verify the corresponding
  # versioned URL and replace `hash`
  version = "1.15.4";

  installer = fetchurl {
    url = "https://launcher.ccpgames.com/eve-online/release/win32/x64/eve-online-${version}+Setup.exe";
    name = "eve-online-${version}+Setup.exe";
    hash = "sha256-Y3P3fHfHZTLSjaYHzYrprXvFj0tyyniJJUxUSeWdRPk=";
  };

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

      export WINEPREFIX="$HOME/Games/eve-online"
      export GAMEID=umu-default
      export STORE=none
      export PROTONPATH=${lib.escapeShellArg proton-ge-bin.steamcompattool}
      # The generic UMU ID has no fixes to apply; skip its no-op wait dialog.
      export PROTONFIXES_DISABLE=1
      # Prevent Wine from creating an unmanaged duplicate desktop shortcut.
      export WINEDLLOVERRIDES="winemenubuilder.exe=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"

      show_help() {
        cat <<'EOF'
      Usage: eve-online [--installer | --help] [launcher arguments...]

        --installer  Run the pinned EVE Online installer again
        --help       Show this help
      EOF
      }

      case "''${1:-}" in
        --help|-h)
          show_help
          exit 0
          ;;
      esac

      mkdir -p "$WINEPREFIX"

      launcher_exe=""
      launcher_workdir=""

      discover_launcher() {
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
        launcher_workdir="$(dirname "$latest_versioned")"
        launcher_exe="$(dirname "$launcher_workdir")/eve-online.exe"

        [[ -f "$launcher_exe" ]]
      }

      run_installer() {
        printf 'Preparing the EVE Online Wine prefix at %s\n' "$WINEPREFIX"
        printf 'Starting the EVE Online %s installer...\n' ${lib.escapeShellArg version}
        # UMU's container can only start in a path that it mounts. The prefix
        # is mounted for every invocation, so use it as the installer cwd.
        (
          cd "$WINEPREFIX"
          umu-run ${lib.escapeShellArg installer} "$@"
        )
      }

      if [[ "''${1:-}" == "--installer" ]]; then
        shift
        run_installer "$@"
        exit $?
      fi

      if ! discover_launcher; then
        run_installer

        # CCP's installer opens the launcher itself. Do not start a second copy;
        # only verify that installation completed for the next desktop launch.
        if ! discover_launcher; then
          printf '%s\n' \
            'EVE Online installation did not create the launcher.' \
            'Run eve-online --installer from a terminal to retry and see its output.' >&2
          exit 1
        fi
        exit 0
      fi

      # Match the working directory and arguments used by CCP's own shortcut.
      cd "$launcher_workdir"
      exec umu-run "$launcher_exe" --product=eve-online "$@"
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "EVE Online";
    genericName = "EVE Online Launcher";
    comment = "EVE Online for NixOS with umu";
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
    description = "EVE Online installer and launcher for Linux";
    homepage = "https://www.eveonline.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
