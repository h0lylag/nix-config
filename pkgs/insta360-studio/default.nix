{
  lib,
  writeShellScriptBin,
  makeDesktopItem,
  symlinkJoin,
  pkgs,
  # install location for the wine prefix
  location ? "$HOME/.local/share/insta360-studio",
  # name used for the launcher
  pname ? "insta360-studio",
  # command to invoke wine at runtime. Keep as "wine" to use the system default from PATH
  wineBin ? "wine",
}:

let
  inherit (lib.strings) optionalString concatStringsSep hasSuffix;

  # pick the first .exe in this directory as the installer (as requested)
  files = builtins.attrNames (builtins.readDir ./.);
  installers = builtins.filter (f: hasSuffix ".exe" f) files;
  installer =
    if installers == [ ] then null else (builtins.toString ./. + "/" + builtins.head installers);

  # icon from the provided URL; hash will need updating on first build
  icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/d/d4/Insta360logo.jpg";
    sha256 = "sha256-vCyJVGj1ep/n0rPDaAI3JbuTBzBkdu64InTLu0u2lTA=";
  };

  # helper tools the script relies on (coreutils/findutils/grep)
  runtimePath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnugrep
  ];

  script = writeShellScriptBin pname ''
            		set -euo pipefail

            		# ensure basic tools are available
            		export PATH=${runtimePath}:$PATH

            		if ! command -v ${wineBin} >/dev/null 2>&1; then
            			echo "Error: '${wineBin}' not found on PATH. Please install Wine system-wide or set wineBin." >&2
            			exit 1
            		fi

            		# define and prepare prefix
    			mkdir -p "${location}"
    			export WINEPREFIX="$(readlink -f "${location}")"
    			export WINEARCH=win64
    			# prevent Wine's winemenubuilder from creating a user .desktop file
    			export WINEDLLOVERRIDES="winemenubuilder.exe=d"

            		# initialize prefix once if it looks empty
            		if [ ! -e "$WINEPREFIX/system.reg" ] || [ ! -d "$WINEPREFIX/drive_c" ]; then
            			echo "Initializing Wine prefix at $WINEPREFIX (win64)"
            			if command -v wineboot >/dev/null 2>&1; then
            				WINEDEBUG=-all wineboot -u || true
            			else
            				# fallback: a no-op that ensures the prefix exists
            				WINEDEBUG=-all ${wineBin} --version >/dev/null || true
            			fi
            		fi

					# Allow providing installer path via CLI or env var, with fallback to repo-local discovery
					DEFAULT_INSTALLER_PATH="${optionalString (installer != null) (toString installer)}"
					INSTALLER_PATH="${optionalString (installer != null) (toString installer)}"

					# Parse optional --installer <path>
					if [ "${1:-}" = "--installer" ]; then
						shift
						if [ "${1:-}" != "" ]; then
							INSTALLER_PATH="${1}"
							shift
						fi
					fi

					# Env var override
					if [ -z "${INSTALLER_PATH}" ] && [ -n "${INSTA360_INSTALLER:-}" ]; then
						INSTALLER_PATH="${INSTA360_INSTALLER}"
					fi

					# Last resort: try a few common locations
					if [ -z "${INSTALLER_PATH}" ]; then
						for p in \
							"$HOME/Downloads" \
							"$PWD"; do
							cand=$(find "${p}" -maxdepth 1 -type f -iname 'Insta360*Studio*.exe' 2>/dev/null | head -n1 || true)
							if [ -n "${cand}" ]; then
								INSTALLER_PATH="${cand}"
								break
							fi
						done
					fi

					if [ -z "$INSTALLER_PATH" ] || [ ! -f "$INSTALLER_PATH" ]; then
						echo "Error: Could not locate the Insta360 Studio installer (.exe)." >&2
						echo "Provide it with one of these options:" >&2
						echo "  1) ${pname} --installer /path/to/Insta360Studio*.exe" >&2
						echo "  2) INSTA360_INSTALLER=/path/to/Insta360Studio*.exe ${pname}" >&2
						echo "  3) Place the installer alongside pkgs/insta360-studio/ (current fallback)." >&2
						exit 1
					fi

            		# simple heuristic to find an installed Insta360 Studio exe
            		find_app() {
            			find "$WINEPREFIX/drive_c" -type f \
            				\( -iname 'Insta360Studio*.exe' -o -iname 'Insta360*Studio*.exe' \) 2>/dev/null | head -n1
            		}

        			APP_EXE="$(find_app || true)"

            		# perform installation if not found
        			if [ -z "''${APP_EXE}" ]; then
            			echo "Running installer: $INSTALLER_PATH"
            			# avoid UAC prompts inside Wine
            			WINEDEBUG=-all WINE_NO_PRIV_ELEVATION=1 ${wineBin} "$INSTALLER_PATH" || true
            			# wait for wineserver to settle, if available
            			if command -v wineserver >/dev/null 2>&1; then
            				wineserver -w || true
            			fi
        				APP_EXE="$(find_app || true)"
            		fi

        			# optional shell for debugging
        			if [ "''${1:-}" = "--shell" ]; then
            			exec ${lib.getExe pkgs.bash}
            		fi

        				if [ -n "''${APP_EXE}" ] && [ -f "''${APP_EXE}" ]; then
        					echo "Launching: ''${APP_EXE}"
        					exec ${wineBin} "''${APP_EXE}" "$@"
            		else
            			echo "Insta360 Studio appears not to be installed. Please re-run and complete the installer UI." >&2
            			exit 2
            		fi
            	'';

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Insta360 Studio";
    exec = "${script}/bin/${pname} %U";
    icon = icon; # absolute path to the fetched icon
    categories = [
      "Graphics"
      "Video"
      "Photography"
    ];
    comment = "Insta360 Studio - 360 video editing software";
    terminal = false;
  };
in

symlinkJoin {
  name = pname;
  paths = [
    script
    desktopItem
  ];
  meta = {
    description = "Insta360 Studio - 360 video editing software";
    homepage = "https://www.insta360.com/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ ];
    platforms = [ "x86_64-linux" ];
  };
}
