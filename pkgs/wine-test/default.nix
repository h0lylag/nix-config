{
  lib,
  stdenv,
  fetchurl,
  makeDesktopItem,
  symlinkJoin,
  writeShellScriptBin,
  wineWowPackages,
  winetricks,
  samba,
  krb5,
  xvfb-run,
  pname ? "eve-online-test",
  location ? "$HOME/Games/eve-online-test",
}:

let
  # Hardcoded EVE installer info
  version = "1.10.1";

  # Fetch the EVE installer
  src = fetchurl {
    url = "https://launcher.ccpgames.com/eve-online/release/win32/x64/eve-online-1.10.1+Setup.exe";
    name = "eve-online-setup-${version}.exe";
    sha256 = "03lvix18kb57cwg0ij5sd87w820i8yk5qpvi3rl597w49k4wwn2f";
  };

  # Create the main script
  script = writeShellScriptBin pname ''
    set -e

    echo "=== EVE Online Wine Launcher ==="

    # Setup paths and environment
    GAME_DIR="${location}"
    mkdir -p "$GAME_DIR"
    export WINEPREFIX="$(readlink -f "$GAME_DIR")"
    export WINEARCH=win64
    export WINEDEBUG=-all
    export WINE_NO_PRIV_ELEVATION=1
    export WINEFSYNC=0
    export WINEESYNC=0

    # Add tools to PATH
    PATH=${
      lib.makeBinPath [
        wineWowPackages.stable
        winetricks
        samba
        krb5
        xvfb-run
      ]
    }:$PATH

    # State tracking files
    PREFIX_SETUP_MARKER="$WINEPREFIX/.eve-prefix-ready"
    DEPS_INSTALLED_MARKER="$WINEPREFIX/.eve-deps-installed"
    EVE_INSTALLED_MARKER="$WINEPREFIX/.eve-installed"

    # EVE launcher paths - use .lnk to avoid JavaScript errors (see: https://forums.eveonline.com/t/lutris-javacript-error/480406)
    EVE_LAUNCHER_EXE="$WINEPREFIX/drive_c/users/$(whoami)/AppData/Local/eve-online/eve-online.exe"
    EVE_LAUNCHER_LNK="$WINEPREFIX/drive_c/users/$(whoami)/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/CCP Games/EVE Launcher.lnk"

    echo "Wine prefix: $WINEPREFIX"

    # Function: Setup Wine prefix
    setup_wine_prefix() {
      echo "Setting up Wine prefix..."
      
      # Remove old 32-bit prefix if it exists
      if [ -f "$WINEPREFIX/system.reg" ] && grep -q "#arch=win32" "$WINEPREFIX/system.reg"; then
        echo "Removing old 32-bit prefix..."
        rm -rf "$WINEPREFIX"
      fi
      
      # Initialize prefix
      wineboot --init
      wineserver -w
      
      # Configure Wine
      echo "Configuring Wine..."
      wine reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /d win10 /f
      wineserver -w
      
      touch "$PREFIX_SETUP_MARKER"
      echo "Wine prefix setup complete"
    }

    # Function: Install dependencies
    install_dependencies() {
      echo "Installing Wine dependencies..."
      winetricks -q msdelta arial tahoma vcrun2022
      touch "$DEPS_INSTALLED_MARKER"
      echo "Dependencies installed"
    }

    # Function: Install EVE Online
    install_eve() {
      echo "Installing EVE Online..."
      wine "${src}"
      if [ -f "$EVE_LAUNCHER_EXE" ]; then
        touch "$EVE_INSTALLED_MARKER"
        echo "EVE Online installation complete"
      else
        echo "ERROR: EVE installation failed - launcher not found"
        exit 1
      fi
    }

    # Function: Launch EVE
    launch_eve() {
      echo "=== Launching EVE Online ==="
      cd "$WINEPREFIX"
      export WINEDLLOVERRIDES="winemenubuilder.exe=d"

      # Try .lnk first (to avoid JavaScript errors), fall back to .exe if it fails
      local LAUNCHER_PATH=""
      local USE_LNK=false
      
      if [ -f "$EVE_LAUNCHER_LNK" ]; then
        echo "Attempting to use .lnk shortcut to avoid JavaScript errors..."
        LAUNCHER_PATH="$EVE_LAUNCHER_LNK"
        USE_LNK=true
      elif [ -f "$EVE_LAUNCHER_EXE" ]; then
        echo "Using direct executable (.exe) - may have JavaScript issues..."
        LAUNCHER_PATH="$EVE_LAUNCHER_EXE"
        USE_LNK=false
      else
        echo "ERROR: No EVE launcher found!"
        return 1
      fi
      
      # Attempt to launch with the selected path
      echo "Launching: $LAUNCHER_PATH"
      
      if [ "$USE_LNK" = true ]; then
        # Try .lnk first
        if ! wine "$LAUNCHER_PATH" 2>/dev/null; then
          echo "WARNING: .lnk shortcut failed, falling back to .exe..."
          if [ -f "$EVE_LAUNCHER_EXE" ]; then
            echo "Using direct executable (.exe) - may have JavaScript issues..."
            exec wine "$EVE_LAUNCHER_EXE"
          else
            echo "ERROR: .exe fallback also failed!"
            return 1
          fi
        fi
      else
        # Direct .exe execution
        exec wine "$LAUNCHER_PATH"
      fi
    }    # Main execution flow

    # 1. Setup Wine prefix if needed
    if [ ! -f "$PREFIX_SETUP_MARKER" ]; then
      setup_wine_prefix
    else
      echo "✓ Wine prefix already configured"
    fi

    # 2. Install dependencies if needed
    if [ ! -f "$DEPS_INSTALLED_MARKER" ]; then
      install_dependencies
    else
      echo "✓ Dependencies already installed"
    fi

    # 3. Install EVE if needed
    if [ ! -f "$EVE_INSTALLED_MARKER" ] || [ ! -f "$EVE_LAUNCHER_EXE" ]; then
      install_eve
    else
      echo "✓ EVE Online already installed"
    fi

    # 4. Launch EVE
    if [ -f "$EVE_LAUNCHER_LNK" ] || [ -f "$EVE_LAUNCHER_EXE" ]; then
      launch_eve
    else
      echo "ERROR: EVE launcher not found"
      echo "  Expected: $EVE_LAUNCHER_LNK"
      echo "  Or: $EVE_LAUNCHER_EXE"
      exit 1
    fi
  '';

  # Create desktop entry
  desktopItem = makeDesktopItem {
    name = pname;
    exec = "${script}/bin/${pname}";
    comment = "EVE Online (Test Version)";
    desktopName = "EVE Online Test";
    categories = [ "Game" ];
  };

in
symlinkJoin {
  name = pname;
  paths = [
    script
    desktopItem
  ];

  meta = with lib; {
    description = "Basic EVE Online installer and launcher for testing";
    homepage = "https://www.eveonline.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
