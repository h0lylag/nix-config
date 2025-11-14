{
  lib,
  stdenv,
  fetchFromGitHub,
  writeShellScript,
  python3,
  qt5,
  wmctrl,
  xdotool,
  kdotool,
  maim,
}:

let
  pythonEnv = python3.withPackages (
    ps: with ps; [
      pyqt5
      xlib
      keyboard
    ]
  );

  launchScript = writeShellScript "eve-l-preview-launcher" ''
        #!/bin/bash

        # Check if we're running as root, if not, escalate with sudo
        if [ "$EUID" -ne 0 ] && [ -z "$SUDO_USER" ]; then
          echo "EVE-L Preview requires root privileges. Escalating with sudo..."
          exec sudo "$0" "$@"
        fi

        # Preserve original user info when running with sudo
        if [ -n "$SUDO_USER" ]; then
          REAL_USER="$SUDO_USER"
          REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
          REAL_UID=$(id -u "$SUDO_USER")
          REAL_GID=$(id -g "$SUDO_USER")
        else
          REAL_USER="$USER"
          REAL_HOME="$HOME"
          REAL_UID="$UID"
          REAL_GID="$GID"
        fi

        # Set up runtime directory for sudo
        if [ -n "$SUDO_USER" ]; then
          export XDG_RUNTIME_DIR="/run/user/$REAL_UID"
          if [ ! -d "$XDG_RUNTIME_DIR" ]; then
            export XDG_RUNTIME_DIR="/tmp/runtime-$REAL_USER"
            mkdir -p "$XDG_RUNTIME_DIR"
            chown "$REAL_UID:$REAL_GID" "$XDG_RUNTIME_DIR"
            chmod 700 "$XDG_RUNTIME_DIR"
          fi
        fi

        # Set up Qt environment variables
        export QT_PLUGIN_PATH="${qt5.qtbase}/lib/qt-${qt5.qtbase.version}/plugins:${qt5.qtimageformats}/lib/qt-${qt5.qtbase.version}/plugins"

        # Force X11 platform for compatibility with window management tools
        export QT_QPA_PLATFORM="xcb"
        export XDG_SESSION_TYPE="x11"
        export QT_AUTO_SCREEN_SCALE_FACTOR="0"
        export QT_SCREEN_SCALE_FACTORS=""

        # Disable KDE notifications that cause warnings
        export KDE_FULL_SESSION=""
        export XDG_CURRENT_DESKTOP=""

        # Ensure DISPLAY is set
        if [ -z "$DISPLAY" ]; then
          export DISPLAY=":0"
        fi

        # Add required tools to PATH
        export PATH="${
          lib.makeBinPath [
            wmctrl
            xdotool
            maim
          ]
        }:$PATH"

        # Copy config file to user's home if it doesn't exist
        if [ ! -f "$REAL_HOME/EVE-L_Preview.json" ] && [ -f "@out@/share/eve-l-preview/EVE-L_Preview.json" ]; then
          cp "@out@/share/eve-l-preview/EVE-L_Preview.json" "$REAL_HOME/EVE-L_Preview.json"
          # Set proper ownership if running as sudo
          if [ -n "$SUDO_USER" ]; then
            chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "$REAL_HOME/EVE-L_Preview.json"
          fi
        fi

        # Set up icon theme paths for Qt
        export QT_ICON_THEME_DIRS="@out@/share/eve-l-preview/assets:@out@/share/eve-l-preview"

        # Set the application directory for asset loading
        export EVE_L_PREVIEW_ROOT="@out@/share/eve-l-preview"
        
        # Add application directory to Python path for relative imports
        export PYTHONPATH="@out@/share/eve-l-preview:${pythonEnv}/lib/python*/site-packages"

        # Override HOME for the application so ~ expands to the real user's home
        export HOME="$REAL_HOME"

        # Launch the application with the application directory as the first argument to sys.path
        exec ${pythonEnv}/bin/python -c "
    import sys, os
    sys.path.insert(0, '@out@/share/eve-l-preview')
    os.chdir('@out@/share/eve-l-preview')
    exec(open('@out@/share/eve-l-preview/main.py').read())
    " "$@"
  '';
in
stdenv.mkDerivation rec {
  pname = "py-eve-l-preview";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "h0lylag";
    repo = "Py-EVE-L_Preview";
    rev = "main";
    hash = "sha256-rGJc42YQI/OsT1Wv/6tYVmtVUwaQoqFNaM3d9f8obC0=";
  };

  nativeBuildInputs = [ ];

  buildInputs = [
    pythonEnv
    qt5.qtbase
    qt5.qtwayland
    qt5.qtimageformats
    wmctrl
    xdotool
    kdotool
    maim
  ];

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    # Create the installation directory
    mkdir -p $out/share/eve-l-preview
    mkdir -p $out/bin

    # Copy all the source files
    cp -r * $out/share/eve-l-preview/

    # Install the launch script
    cp ${launchScript} $out/bin/py-eve-l-preview
    chmod +x $out/bin/py-eve-l-preview

    # Replace @out@ placeholder with actual output path
    substituteInPlace $out/bin/py-eve-l-preview \
      --replace "@out@" "$out"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Quick and dirty EVE-O Preview implementation for Linux systems";
    homepage = "https://github.com/h0lylag/Py-EVE-L_Preview";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "py-eve-l-preview";
  };
}
