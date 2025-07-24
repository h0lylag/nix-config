{
  lib,
  makeDesktopItem,
  symlinkJoin,
  writeShellScriptBin,
  gamescope,
  winetricks,
  # Use the 32+64-bit Wine build by default
  wine ? pkgs.wine64,
  wineprefix-preparer,
  umu-launcher,
  proton-ge-bin,
  wineFlags ? "",
  pname ? "eve-online",
  location ? "$HOME/Games/eve-online",
  tricks ? [
    "msdelta"
    "corefonts"
    "tahoma"
    "vcrun2022"
  ],
  useUmu ? false,
  protonPath ? "${proton-ge-bin.steamcompattool}/",
  protonVerbs ? [ "waitforexitandrun" ],
  wineDllOverrides ? [ "winemenubuilder.exe=d" ],
  gameScopeEnable ? false,
  gameScopeArgs ? [ ],
  preCommands ? "",
  postCommands ? "",
  pkgs,
}:

let
  inherit (lib.strings) concatStringsSep optionalString toShellVars;
  info = builtins.fromJSON (builtins.readFile ./info.json);
  inherit (info) version;

  src = pkgs.fetchurl {
    url = info.url;
    name = "eve-online-setup-${version}.exe";
    inherit (info) hash;
  };

  gameScope = lib.strings.optionalString gameScopeEnable "${gamescope}/bin/gamescope ${concatStringsSep " " gameScopeArgs} --";

  libs = with pkgs; [
    freetype
    vulkan-loader
  ];

  script = writeShellScriptBin pname ''
    # disable winetricks version check
    export WINETRICKS_LATEST_VERSION_CHECK=disabled
    # Ensure we're using 64-bit architecture for all subsequent Wine calls
    export WINEARCH=win64

    # define prefix path
    mkdir -p "${location}"
    export WINEPREFIX="$(readlink -f "${location}")"

    # auto-init/update the prefix (handles both 32+64-bit via wineWowPackages)
    ${lib.getExe wineprefix-preparer}


    ${optionalString (!useUmu) ''
      export WINEFSYNC=1
      export WINEESYNC=1
      export WINEDLLOVERRIDES="${concatStringsSep ";" wineDllOverrides}"
      export WINEDEBUG=-all
    ''}

    export GAMEID="eve-online"
    export STORE="none"

    # ensure wine & winetricks (and umu-launcher when used) are on PATH
    PATH=${
      lib.makeBinPath (
        if useUmu then
          [ umu-launcher ]
        else
          [
            wine
            winetricks
          ]
      )
    }:$PATH

    export LD_LIBRARY_PATH=${lib.makeLibraryPath libs}:$LD_LIBRARY_PATH

    EVE_LAUNCHER="$WINEPREFIX/drive_c/users/$(whoami)/AppData/Local/EVE Online/eve-online.exe"

    # install via UMU/Proton if requested
    ${
      if useUmu then
        ''
          export PROTON_VERBS="${concatStringsSep "," protonVerbs}"
          export PROTONPATH="${protonPath}"
          if [ ! -f "$EVE_LAUNCHER" ]; then
            umu-run "$src" /silent
          fi
        ''
      else
        ''
          # install required winetricks components
          ${toShellVars {
            inherit tricks;
            tricksInstalled = 1;
          }}
          for t in "${"\${tricks[@]}"}"; do
            if ! winetricks list-installed | grep -qw "$t"; then
              echo "winetricks: Installing $t"
              winetricks -q -f "$t"
              tricksInstalled=0
            fi
          done
          [ "$tricksInstalled" -eq 0 ] && wineserver -k

          # run the installer interactively if launcher not yet present
          if [ ! -e "$EVE_LAUNCHER" ]; then
            echo "→ Running EVE Online installer..."
            WINE_NO_PRIV_ELEVATION=1 wine "$src"
          fi
        ''
    }

    # move into the prefix for launch
    cd "$WINEPREFIX"

    # optional shell entry
    if [ "${"\${1:-}"}" = "--shell" ]; then
      exec ${lib.getExe pkgs.bash}
    fi

    # launch with Gamescope or vanilla wine
    ${preCommands}
    ${
      if useUmu then
        ''
          ${gameScope} umu-run "$EVE_LAUNCHER" "$@"
        ''
      else
        ''
          if [[ -t 1 ]]; then
            ${gameScope} wine ${wineFlags} "$EVE_LAUNCHER" "$@"
          else
            export LOG_DIR=$(mktemp -d)
            ${gameScope} wine ${wineFlags} "$EVE_LAUNCHER" "$@" >"$LOG_DIR/out" 2>"$LOG_DIR/err"
          fi
          wineserver -w
        ''
    }
    ${postCommands}
  '';

  # desktop integration
  desktopItems = makeDesktopItem {
    name = pname;
    exec = "${script}/bin/${pname} %U";
    comment = "EVE Online Launcher";
    desktopName = "EVE Online";
    categories = [ "Game" ];
    mimeTypes = [ "application/x-eve-online-launcher" ];
  };
in

symlinkJoin {
  name = pname;
  paths = [
    desktopItems
    script
  ];
  meta = {
    description = "EVE Online installer and launcher";
    homepage = "https://www.eveonline.com/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ ];
    platforms = [ "x86_64-linux" ];
  };
}
