{
  lib,
  fetchurl,
  writeShellScriptBin,
  symlinkJoin,
  makeDesktopItem,
  wine,
  winetricks,
}:

let
  installerExe = fetchurl {
    url = "https://launcher.ccpgames.com/eve-online/release/win32/x64/eve-online-latest+Setup.exe";
    sha256 = "16lzi962fpcnfxrga526xm2g155g8r6n1xzr292rabmzi3lbnbb2";
  };

  wrapper = writeShellScriptBin "eve-online" ''
    #!/usr/bin/env bash
    export WINEPREFIX="$HOME/Games/eve-online"
    #export WINEARCH=win64
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"
    export WINEDEBUG=-all

    # ensure wine, wineserver & winetricks are on our PATH
    PATH=${
      lib.makeBinPath [
        wine
        winetricks
      ]
    }:$PATH

    # bootstrap the prefix with .NET 4.8 + VC++ 2022
    for trick in dotnet48 vcrun2022; do
      if ! winetricks list-installed | grep -qw "$trick"; then
        echo "winetricks: installing $trick"
        winetricks -q "$trick"
      fi
    done

    # restart wineserver so the new runtimes take effect
    wineserver -k

    # install the launcher EXE if missing
    TARGET="$WINEPREFIX/drive_c/Program Files/EVE Online"
    mkdir -p "$TARGET"
    if [ ! -f "$TARGET/eve-online-latest+Setup.exe" ]; then
      echo "Copying installer into prefix…"
      cp ${installerExe} "$TARGET/eve-online-latest+Setup.exe"
      wine "$TARGET/eve-online-latest+Setup.exe"
    fi

    # finally, launch
    echo "Try to launch EVE Online…"
    exec wine "$TARGET/EVEOnlineLauncher.exe" "$@"
  '';

  desktop = makeDesktopItem {
    name = "eve-online"; # filename
    desktopName = "EVE Online"; # Name= in the .desktop
    exec = "${wrapper} %U";
    # icon     = ./eve-online.png;  # supply your 64×64 PNG here
    comment = "EVE Online Launcher";
    categories = [ "Game" ];
  };
in

symlinkJoin {
  name = "eve-online";
  paths = [
    wrapper
    desktop
  ];
  buildInputs = [
    wine
    winetricks
  ];

  meta = with lib; {
    description = "EVE Online wrapped for Wine (installs .NET 4.8 & VC++ 2022 at runtime)";
    homepage = "https://www.eveonline.com/";
    license = licenses.unfree;
    platforms = platforms.unix;
  };
}
