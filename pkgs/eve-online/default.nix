{
  lib,
  makeDesktopItem,
  symlinkJoin,
  writeShellScriptBin,
  gamescope,
  winetricks,
  wine,
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
  enableGlCache ? true,
  glCacheSize ? 10737418240, # 10GB
  disableEac ? false,
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
    export WINETRICKS_LATEST_VERSION_CHECK=disabled
    export WINEARCH="win64"
    mkdir -p "${location}"
    export WINEPREFIX="$(readlink -f "${location}")"
    ${optionalString (!useUmu) ''
      export WINEFSYNC=1
      export WINEESYNC=1
      export WINEDLLOVERRIDES="${concatStringsSep ";" wineDllOverrides}"
      export WINEDEBUG=-all
    ''}

    export GAMEID="eve-online"
    export STORE="none"

    ${optionalString enableGlCache ''
      export __GL_SHADER_DISK_CACHE=1
      export __GL_SHADER_DISK_CACHE_SIZE=${builtins.toString glCacheSize}
      export __GL_SHADER_DISK_CACHE_PATH="$WINEPREFIX"
      export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
      export MESA_SHADER_CACHE_DIR="$WINEPREFIX"
      export MESA_SHADER_CACHE_MAX_SIZE="${builtins.toString glCacheSize}"
      export DXVK_ENABLE_NVAPI=1
    ''}

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

    ${
      if useUmu then
        ''
          export PROTON_VERBS="${concatStringsSep "," protonVerbs}"
          export PROTONPATH="${protonPath}"
          if [ ! -f "$EVE_LAUNCHER" ]; then umu-run "$src" /silent; fi
        ''
      else
        ''
          ${toShellVars {
            inherit tricks;
            tricksInstalled = 1;
          }}
          ${lib.getExe wineprefix-preparer}
          for trick in "${"\${tricks[@]}"}"; do
            if ! winetricks list-installed | grep -qw "$trick"; then
              echo "winetricks: Installing $trick"
              winetricks -q -f "$trick"
              tricksInstalled=0
            fi
          done
          if [ "$tricksInstalled" -eq 0 ]; then wineserver -k; fi
          if [ ! -e "$EVE_LAUNCHER" ]; then
            WINE_NO_PRIV_ELEVATION=1 wine "$src" /silent
            wineserver -k
          fi
        ''
    }

    ${lib.optionalString disableEac ''
      export EOS_USE_ANTICHEATCLIENTNULL=1
    ''}
    cd "$WINEPREFIX"

    if [ "${"\${1:-}"}" = "--shell" ]; then
      exec ${lib.getExe pkgs.bash}
    fi

    if [ -z "$DISPLAY" ]; then set -- "$@" "--in-process-gpu"; fi

    if command -v gamemoderun > /dev/null 2>&1; then gamemode="gamemoderun"; else gamemode=""; fi

    ${preCommands}
    ${
      if useUmu then
        ''
          ${gameScope} $gamemode umu-run "$EVE_LAUNCHER" "$@"
        ''
      else
        ''
          if [[ -t 1 ]]; then
            ${gameScope} $gamemode wine ${wineFlags} "$EVE_LAUNCHER" "$@"
          else
            export LOG_DIR=$(mktemp -d)
            ${gameScope} $gamemode wine ${wineFlags} "$EVE_LAUNCHER" "$@" >"$LOG_DIR/out" 2>"$LOG_DIR/err"
          fi
          wineserver -w
        ''
    }
    ${postCommands}
  '';

  # icon disabled for now
  # icon = pkgs.fetchurl {
  #   url = "https://launcher.ccpgames.com/eve-online/release/ui/favicon.ico";
  #   sha256 = info.hash;
  #};

  desktopItems = makeDesktopItem {
    name = pname;
    exec = "${script}/bin/${pname} %U";
    #   inherit icon;  # icon disabled
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
