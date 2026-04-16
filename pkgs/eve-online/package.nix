{
  lib,
  makeDesktopItem,
  stdenvNoCC,
  writeScript,
  makeWrapper,
  gamescope,
  winetricks,
  # Use the 32+64-bit Wine build by default
  wine ? pkgs.wineWowPackages.stable,
  wineprefix-preparer,
  umu-launcher,
  proton-ge-bin,
  fetchurl,
  bash,
  wineFlags ? "",
  pname ? "eve-online",
  location ? "$HOME/Games/eve-online",
  tricks ? [
    "msdelta"
    "arial"
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
  inherit (lib) optional;
  info = builtins.fromJSON (builtins.readFile ./info.json);

  gameScope = lib.strings.optionalString gameScopeEnable "gamescope ${concatStringsSep " " gameScopeArgs} --";

  libs = with pkgs; [
    freetype
    vulkan-loader
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit (info) version;
  inherit pname;

  src = fetchurl {
    url = info.url;
    name = "eve-online-setup-${finalAttrs.version}.exe";
    inherit (info) hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;
  dontBuild = true;

  desktopItem = makeDesktopItem {
    name = finalAttrs.pname;
    exec = "${finalAttrs.pname} %U";
    comment = "EVE Online Launcher";
    desktopName = "EVE Online";
    categories = [ "Game" ];
    mimeTypes = [ "application/x-eve-online-launcher" ];
  };

  script = writeScript "${finalAttrs.pname}" ''
    # disable winetricks version check
    export WINETRICKS_LATEST_VERSION_CHECK=disabled

    # define prefix path
    mkdir -p "${location}"
    export WINEPREFIX="$(readlink -f "${location}")"

    # Initialize prefix cleanly if it doesn't exist
    if [ ! -f "$WINEPREFIX/system.reg" ]; then
      echo "Initializing WoW64 prefix (64-bit with 32-bit subsystem)..."
      # MUST set WINEARCH=win64 during creation to get WoW64 prefix
      export WINEARCH=win64
      wineboot -u
      wineserver -w
      
      # Set Windows 10 mode (required by EVE Online)
      wine reg add 'HKEY_CURRENT_USER\Software\Wine' /v Version /d win10 /f
      
      # Unset WINEARCH after creation - the arch is baked into the prefix
      unset WINEARCH
    else
      # Verify existing prefix is WoW64 (has both syswow64 and system32)
      if [ ! -d "$WINEPREFIX/drive_c/windows/syswow64" ]; then
        echo "ERROR: Existing prefix at $WINEPREFIX is not WoW64!"
        echo "EVE Online requires a 64-bit prefix with 32-bit subsystem."
        echo "Please remove the prefix and try again:"
        echo "  rm -rf \"$WINEPREFIX\""
        exit 1
      fi
    fi


    ${optionalString (!useUmu) ''
      # EVE Online requires esync/fsync DISABLED per Lutris config
      export WINEFSYNC=0
      export WINEESYNC=0
      export WINEDLLOVERRIDES="${concatStringsSep ";" wineDllOverrides}"
      export WINEDEBUG=-all
    ''}

    export GAMEID="eve-online"
    export STORE="none"

    # wine/winetricks are added to PATH via wrapProgram, ensuring they're the same version
    export LD_LIBRARY_PATH=${lib.makeLibraryPath libs}:$LD_LIBRARY_PATH

    # EVE launcher installs to Local AppData
    EVE_LAUNCHER="$WINEPREFIX/drive_c/users/$USER/AppData/Local/eve-online/eve-online.exe"

    # install via UMU/Proton if requested
    ${
      if useUmu then
        ''
          export PROTON_VERBS="${concatStringsSep "," protonVerbs}"
          export PROTONPATH="${protonPath}"
          if [ ! -f "$EVE_LAUNCHER" ]; then
            umu-run "@EVE_INSTALLER@" /S
          fi
        ''
      else
        ''
          # install required winetricks components (if any specified)
          ${optionalString (tricks != [ ]) ''
            ${toShellVars {
              inherit tricks;
              tricksInstalled = 1;
            }}
            for t in "''${tricks[@]}"; do
              if ! winetricks list-installed | grep -qw "$t"; then
                echo "winetricks: Installing $t"
                winetricks -q -f "$t" || echo "Warning: winetricks $t failed, continuing anyway"
                tricksInstalled=0
              fi
            done
            [ "$tricksInstalled" -eq 0 ] && wineserver -k
          ''}

          # run the installer if launcher not yet present
          if [ ! -e "$EVE_LAUNCHER" ]; then
            echo "→ Running EVE Online installer..."
            # Use wine (not wine64) for the installer like RSI launcher does
            WINE_NO_PRIV_ELEVATION=1 WINEDLLOVERRIDES="winemenubuilder.exe=d" wine @EVE_INSTALLER@ /S
            echo "→ Waiting for installation to complete..."
            wineserver -k
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
          # Use wine like RSI launcher - it handles both 32-bit and 64-bit correctly
          if [[ -t 1 ]]; then
            ${gameScope} wine ${wineFlags} "$EVE_LAUNCHER" "$@"
          else
            export LOG_DIR=$(mktemp -d)
            echo "Working around known launcher error by outputting logs to $LOG_DIR"
            ${gameScope} wine ${wineFlags} "$EVE_LAUNCHER" "$@" >"$LOG_DIR/out" 2>"$LOG_DIR/err"
          fi
          wineserver -w
        ''
    }
    ${postCommands}
  '';

  installPhase = ''
    # Install the script
    install -D -m744 "${finalAttrs.script}" $out/bin/${finalAttrs.pname}

    # Install the installer exe to lib directory
    install -D -m444 "$src" "$out/lib/eve-online-setup-${finalAttrs.version}.exe"

    # Install desktop file
    install -D -m444 "${finalAttrs.desktopItem}/share/applications/${finalAttrs.pname}.desktop" "$out/share/applications/${finalAttrs.pname}.desktop"

    # Substitute the installer path placeholder
    substituteInPlace "$out/bin/${finalAttrs.pname}" \
      --replace-fail '@EVE_INSTALLER@' "$out/lib/eve-online-setup-${finalAttrs.version}.exe"

    # Wrap the program to ensure wine/winetricks are in PATH
    wrapProgram $out/bin/${finalAttrs.pname} \
      --prefix PATH : ${
        lib.makeBinPath (
          (
            if useUmu then
              [ umu-launcher ]
            else
              [
                wine
                winetricks
                wineprefix-preparer
              ]
          )
          ++ optional gameScopeEnable gamescope
        )
      }
  '';

  meta = {
    description = "EVE Online installer and launcher";
    homepage = "https://www.eveonline.com/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = finalAttrs.pname;
  };
})
