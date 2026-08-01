{
  coreutils,
  fetchurl,
  icoutils,
  lib,
  makeDesktopItem,
  pkgsCross,
  proton-ge-bin,
  runCommand,
  symlinkJoin,
  systemd,
  umu-launcher,
  umu-launcher-unwrapped,
  util-linux,
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

  requireContainerNsenterPatch = builtins.toFile "umu-require-container-nsenter.patch" (
    lib.concatStringsSep "\n" [
      "diff --git a/umu/umu_run.py b/umu/umu_run.py"
      "index 1db7013..8c52ee2 100644"
      "--- a/umu/umu_run.py"
      "+++ b/umu/umu_run.py"
      "@@ -405,6 +405,13 @@ def build_command("
      "             log.info(\"Failed to find bus name %s (retry %s)\", pfx_bus, trial + 1)"
      "             time.sleep(1)"
      " "
      "+        if not nsenter and os.environ.get(\"UMU_CONTAINER_NSENTER_REQUIRED\") == \"1\":"
      "+            msg = ("
      "+                \"Required container launcher service is unavailable: \""
      "+                f\"{pfx_bus}\""
      "+            )"
      "+            raise RuntimeError(msg)"
      "+"
      "     is_nsenter: bool = bool(nsenter)"
      "     return ("
      "         *nsenter,"
      "@@ -1027,4 +1034,7 @@ def main(args: tuple[str, list[str]] | str) -> int:"
      "         # Configure the environment"
      "         set_env(env, args)"
      "-        if env.get(\"UMU_CONTAINER_NSENTER\") == \"1\":"
      "+        if ("
      "+            env.get(\"UMU_CONTAINER_NSENTER\") == \"1\""
      "+            or os.environ.get(\"UMU_CONTAINER_NSENTER_CREATE\") == \"1\""
      "+        ):"
      "             env[\"STEAM_COMPAT_LAUNCHER_SERVICE\"] = layer.launcher_service"
    ]
    + "\n"
  );

  # UMU's container re-entry switch normally falls back to creating a new
  # container when its launcher service cannot be found. That is unsafe for a
  # shared Wine prefix: a short D-Bus race becomes a second concurrent runtime.
  strictUmuLauncherUnwrapped = umu-launcher-unwrapped.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ requireContainerNsenterPatch ];
  });
  strictUmuLauncher = umu-launcher.override {
    umu-launcher-unwrapped = strictUmuLauncherUnwrapped;
  };

  runtimeAnchorSource = builtins.toFile "eve-online-runtime-anchor.c" ''
    #include <windows.h>

    int WINAPI WinMain(
        HINSTANCE instance,
        HINSTANCE previous_instance,
        LPSTR command_line,
        int show_command
    ) {
        (void) instance;
        (void) previous_instance;
        (void) command_line;
        (void) show_command;
        Sleep(INFINITE);
        return 0;
    }
  '';

  runtimeAnchorProgram = pkgsCross.mingwW64.stdenv.mkDerivation {
    pname = "eve-online-runtime-anchor-program";
    version = "1";
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      "$CC" -Os -s -mwindows \
        ${lib.escapeShellArg runtimeAnchorSource} \
        -o eve-online-runtime-anchor.exe
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 eve-online-runtime-anchor.exe \
        "$out/bin/eve-online-runtime-anchor.exe"
      runHook postInstall
    '';
  };

  protonProcessSupervisor = writeShellApplication {
    name = "eve-proton-process-supervisor";
    runtimeInputs = [
      coreutils
      util-linux
    ];
    text = ''
      if (( $# == 0 )); then
        printf 'Usage: eve-proton-process-supervisor <command> [arguments...]\n' >&2
        exit 2
      fi

      child_pid=""
      stop_requested=0

      # shellcheck disable=SC2329 # Invoked indirectly by trap.
      forward_term() {
        stop_requested=1
        if [[ -z "$child_pid" ]]; then
          return
        fi

        trap "" TERM INT
        kill -TERM -- "-$child_pid" 2>/dev/null || true
        for _ in {1..30}; do
          if ! kill -0 -- "-$child_pid" 2>/dev/null; then
            return
          fi
          sleep 0.1
        done
        kill -KILL -- "-$child_pid" 2>/dev/null || true
      }
      trap forward_term TERM INT

      setsid "$@" &
      child_pid="$!"
      if (( stop_requested )); then
        forward_term
      fi

      status=0
      wait "$child_pid" || status="$?"
      exit "$status"
    '';
  };

  protonEntrypoint = writeShellApplication {
    name = "proton";
    text = ''
      exec ${protonProcessSupervisor}/bin/eve-proton-process-supervisor \
        ${proton-ge-bin.steamcompattool}/proton "$@"
    '';
  };

  eveProton = symlinkJoin {
    name = "proton-ge-eve-signal-forwarding";
    paths = [ proton-ge-bin.steamcompattool ];
    postBuild = ''
      rm "$out/proton"
      ln -s ${protonEntrypoint}/bin/proton "$out/proton"
    '';
  };

  umuEnvironment = ''
    export GAMEID=umu-default
    export STORE=none
    export PROTONPATH=${lib.escapeShellArg eveProton}
    # The generic UMU ID has no fixes to apply; skip its no-op wait dialog.
    export PROTONFIXES_DISABLE=1
    # EVE does not need Proton's Xalia accessibility bridge. It repeatedly
    # queries windows after their processes exit, flooding launcher stderr.
    export PROTON_USE_XALIA=0
    # Prevent Wine from creating an unmanaged duplicate desktop shortcut.
    export WINEDLLOVERRIDES="winemenubuilder.exe=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
  '';

  runtimeAnchor = writeShellApplication {
    name = "eve-online-runtime-anchor";
    runtimeInputs = [
      coreutils
      systemd
      strictUmuLauncher
    ];
    text = ''
      umask 077

      if (( $# != 3 )); then
        printf 'Usage: eve-online-runtime-anchor <Wine prefix> <EVE workdir> <systemd unit>\n' >&2
        exit 2
      fi

      WINEPREFIX="$(realpath -m -- "$1")"
      eve_workdir="$(realpath -e -- "$2")"
      runtime_unit="$3"

      if [[ ! -d "$WINEPREFIX" ]]; then
        printf 'EVE Wine prefix does not exist: %s\n' "$WINEPREFIX" >&2
        exit 2
      fi
      if [[ ! -d "$eve_workdir" ]]; then
        printf 'EVE working directory does not exist: %s\n' "$eve_workdir" >&2
        exit 2
      fi
      if [[ "$runtime_unit" != eve-online-runtime-*.service ]]; then
        printf 'Invalid EVE runtime unit name: %s\n' "$runtime_unit" >&2
        exit 2
      fi

      export WINEPREFIX
      export STEAM_COMPAT_INSTALL_PATH="$eve_workdir"
      # The anchor must create a fresh container even when clients from an
      # earlier batch still own the prefix alias. Client processes, never the
      # anchor, opt into UMU's container re-entry path.
      unset UMU_CONTAINER_NSENTER UMU_CONTAINER_NSENTER_REQUIRED
      # Ask the package-specific UMU patch to publish a launcher service while
      # deliberately skipping discovery/re-entry into any older prefix bus.
      export UMU_CONTAINER_NSENTER_CREATE=1
      export PROTON_VERB=run
      ${umuEnvironment}

      prefix_hash="$(printf '%s' "$WINEPREFIX" | md5sum)"
      prefix_hash="''${prefix_hash%% *}"
      bus_name="com.steampowered.App$prefix_hash"

      if [[ -n "''${UMU_FOLDERS_PATH:-}" ]]; then
        umu_root="$UMU_FOLDERS_PATH/umu"
      else
        umu_root="''${XDG_DATA_HOME:-$HOME/.local/share}/umu"
      fi
      launch_client="$umu_root/steamrt4/pressure-vessel/bin/steam-runtime-launch-client"
      if [[ ! -x "$launch_client" ]]; then
        printf 'UMU steamrt4 launch client is unavailable: %s\n' "$launch_client" >&2
        exit 1
      fi

      get_bus_pid() {
        local reply

        if ! reply="$(
          busctl --user call \
            org.freedesktop.DBus \
            /org/freedesktop/DBus \
            org.freedesktop.DBus \
            GetConnectionUnixProcessID \
            s "$bus_name" \
            2>/dev/null
        )"; then
          return 1
        fi
        [[ "$reply" =~ ^u[[:space:]]+([0-9]+)$ ]] || return 1
        printf '%s\n' "''${BASH_REMATCH[1]}"
      }

      runtime_is_owned_by_unit() {
        local bus_pid
        local entry
        local -a entries=()

        if ! bus_pid="$(get_bus_pid)"; then
          return 1
        fi
        if [[ ! -r "/proc/$bus_pid/cgroup" ]] \
          || ! grep -Fq "/$runtime_unit" "/proc/$bus_pid/cgroup"; then
          return 1
        fi

        # Match UMU's own discovery interface in addition to checking D-Bus
        # ownership. Both must refer to the launcher inside this systemd unit.
        mapfile -t entries < <("$launch_client" --list 2>/dev/null)
        for entry in "''${entries[@]}"; do
          if [[ "$entry" == "--bus-name=$bus_name" ]]; then
            return 0
          fi
        done
        return 1
      }

      anchor_pid=""
      # shellcheck disable=SC2329 # Invoked indirectly by trap.
      stop_anchor() {
        systemd-notify --stopping --status="Stopping shared EVE runtime" || true
        if [[ -n "$anchor_pid" ]] && kill -0 "$anchor_pid" 2>/dev/null; then
          kill -TERM "$anchor_pid" 2>/dev/null || true
        fi
      }
      trap stop_anchor TERM INT

      cd "$eve_workdir"
      umu-run ${runtimeAnchorProgram}/bin/eve-online-runtime-anchor.exe >/dev/null &
      anchor_pid="$!"

      while ! runtime_is_owned_by_unit; do
        if ! kill -0 "$anchor_pid" 2>/dev/null; then
          status=0
          wait "$anchor_pid" || status="$?"
          if (( status == 0 )); then
            printf 'Shared EVE runtime anchor exited unexpectedly\n' >&2
            exit 1
          fi
          exit "$status"
        fi
        sleep 0.1
      done

      systemd-notify --ready --status="Shared EVE runtime is ready"

      status=0
      wait "$anchor_pid" || status="$?"
      if (( status == 0 )); then
        printf 'Shared EVE runtime anchor exited unexpectedly\n' >&2
        exit 1
      fi
      exit "$status"
    '';
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
      ${umuEnvironment}

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

  clientRunner = writeShellApplication {
    name = "${pname}-client";
    runtimeInputs = [
      coreutils
      systemd
      strictUmuLauncher
      util-linux
    ];
    text = ''
      umask 077

      show_help() {
        cat <<'EOF'
      Usage: eve-online-client <absolute path to exefile.exe> [EVE arguments...]

      Runs an EVE client executable through this package's UMU and Proton setup.
      The executable must be located beneath the Wine prefix's drive_c directory.
      EOF
      }

      case "''${1:-}" in
        --help|-h)
          show_help
          exit 0
          ;;
        "")
          show_help >&2
          exit 2
          ;;
      esac

      unresolved_client_exe="$1"
      shift
      if [[ "$unresolved_client_exe" != /* ]]; then
        printf 'EVE client executable path must be absolute: %s\n' "$unresolved_client_exe" >&2
        exit 2
      fi
      if ! client_exe="$(realpath -e -- "$unresolved_client_exe" 2>/dev/null)"; then
        printf 'EVE client executable does not exist: %s\n' "$unresolved_client_exe" >&2
        exit 2
      fi
      if [[ ! -f "$client_exe" ]]; then
        printf 'EVE client executable is not a file: %s\n' "$unresolved_client_exe" >&2
        exit 2
      fi

      case "$client_exe" in
        */drive_c/*)
          # Use the final drive_c component so prefixes remain valid even when
          # a parent directory is also named drive_c.
          WINEPREFIX="''${client_exe%/drive_c/*}"
          if [[ -z "$WINEPREFIX" ]]; then
            printf 'EVE client executable has no Wine prefix before drive_c: %s\n' "$client_exe" >&2
            exit 2
          fi
          export WINEPREFIX
          ;;
        *)
          printf 'EVE client executable is not beneath a Wine prefix drive_c: %s\n' "$client_exe" >&2
          exit 2
          ;;
      esac

      ${umuEnvironment}

      start_eve_runtime() {
        local eve_workdir="$1"
        local bus_name
        local bus_pid
        local bus_reply
        local prefix_hash
        local runtime_unit
        local variable
        local -a runtime_environment=()

        prefix_hash="$(printf '%s' "$WINEPREFIX" | md5sum)"
        prefix_hash="''${prefix_hash%% *}"
        bus_name="com.steampowered.App$prefix_hash"
        runtime_unit="eve-online-runtime-$prefix_hash.service"

        runtime_is_owned_by_unit() {
          if ! bus_reply="$(
            busctl --user call \
              org.freedesktop.DBus \
              /org/freedesktop/DBus \
              org.freedesktop.DBus \
              GetConnectionUnixProcessID \
              s "$bus_name" \
              2>/dev/null
          )"; then
            return 1
          fi
          [[ "$bus_reply" =~ ^u[[:space:]]+([0-9]+)$ ]] || return 1
          bus_pid="''${BASH_REMATCH[1]}"
          [[ -r "/proc/$bus_pid/cgroup" ]] \
            && grep -Fq "/$runtime_unit" "/proc/$bus_pid/cgroup"
        }

        for variable in \
          DISPLAY WAYLAND_DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS \
          XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP \
          LANG LC_ALL DRI_PRIME VK_ICD_FILENAMES AMD_VULKAN_ICD \
          __NV_PRIME_RENDER_OFFLOAD __GLX_VENDOR_LIBRARY_NAME \
          NVIDIA_VISIBLE_DEVICES MANGOHUD
        do
          if [[ -v "$variable" ]]; then
            runtime_environment+=(--setenv="$variable=''${!variable}")
          fi
        done

        if systemctl --user is-active --quiet "$runtime_unit"; then
          if runtime_is_owned_by_unit; then
            return 0
          fi
          printf 'Active EVE runtime does not own its prefix bus: %s\n' "$runtime_unit" >&2
          return 1
        fi

        # A failed transient unit cannot be replaced under the same name. It
        # is safe to stop here because is-active proved it owns no live anchor.
        systemctl --user stop "$runtime_unit" 2>/dev/null || true
        systemctl --user reset-failed "$runtime_unit" 2>/dev/null || true
        for _ in {1..50}; do
          if [[ "$(
            systemctl --user show "$runtime_unit" --property=LoadState --value 2>/dev/null \
              || true
          )" == "not-found" ]]; then
            break
          fi
          sleep 0.1
        done

        systemd-run \
          --user \
          --quiet \
          --collect \
          --unit="$runtime_unit" \
          --description="Shared EVE Online runtime for $WINEPREFIX" \
          --service-type=notify \
          --property=NotifyAccess=all \
          --property=KillMode=control-group \
          --property=PartOf=graphical-session.target \
          --property=Restart=no \
          --property=TimeoutStartSec=45s \
          --property=TimeoutStopSec=10s \
          --property=LimitNOFILE=524288 \
          --property=StandardOutput=null \
          --property=StandardError=journal \
          "''${runtime_environment[@]}" \
          ${runtimeAnchor}/bin/eve-online-runtime-anchor \
          "$WINEPREFIX" \
          "$eve_workdir" \
          "$runtime_unit"

        if ! systemctl --user is-active --quiet "$runtime_unit" \
          || ! runtime_is_owned_by_unit; then
          printf 'Shared EVE runtime failed to become active: %s\n' "$runtime_unit" >&2
          return 1
        fi
      }

      # UMU debug output includes the complete child command, including EVE's
      # token-bearing arguments. Keep direct-client launches at normal logging.
      unset UMU_LOG

      client_workdir="$(dirname "$client_exe")"

      # The first callers can all block on the shared runtime becoming ready.
      # Keep the prefix gate until each client creates its initial game log.
      # EVE writes that file only after loading code.ccp, so the next client
      # cannot overlap the startup phase that intermittently failed imports.
      prefix_hash="$(printf '%s' "$WINEPREFIX" | md5sum)"
      prefix_hash="''${prefix_hash%% *}"
      launch_lock_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/eve-online"
      mkdir -p "$launch_lock_dir"
      exec {launch_lock_fd}>"$launch_lock_dir/$prefix_hash.launch.lock"
      flock "$launch_lock_fd"

      start_eve_runtime "$client_workdir"

      game_log_dir="$WINEPREFIX/drive_c/users/steamuser/Documents/EVE/logs/Gamelogs"
      startup_marker="$launch_lock_dir/$prefix_hash.$$.startup"
      touch "$startup_marker"
      startup_gate_parent_pid="$$"

      # This monitor inherits the locked descriptor. Closing the parent's copy
      # below lets the runner exec UMU while the monitor continues to exclude
      # the next launch. It releases the lock at EVE's startup milestone, when
      # this runner exits, or after a bounded timeout.
      (
        startup_deadline=$((SECONDS + 45))
        while (( SECONDS < startup_deadline )); do
          if ! kill -0 "$startup_gate_parent_pid" 2>/dev/null; then
            break
          fi

          shopt -s nullglob
          for game_log in "$game_log_dir"/????????_??????.txt; do
            if [[ "$game_log" -nt "$startup_marker" ]]; then
              rm -f -- "$startup_marker"
              exit 0
            fi
          done
          shopt -u nullglob
          sleep 0.1
        done

        if kill -0 "$startup_gate_parent_pid" 2>/dev/null; then
          printf 'Timed out waiting for EVE startup milestone; releasing prefix gate\n' >&2
        fi
        rm -f -- "$startup_marker"
      ) &

      # Do not explicitly unlock: the monitor's inherited descriptor must keep
      # the flock alive after this copy is closed.
      exec {launch_lock_fd}>&-
      unset UMU_CONTAINER_NSENTER_CREATE
      export UMU_CONTAINER_NSENTER=1
      export UMU_CONTAINER_NSENTER_REQUIRED=1

      cd "$client_workdir"
      exec umu-run "$client_exe" "$@"
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
    clientRunner
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
