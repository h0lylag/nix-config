{
  coreutils,
  fetchurl,
  icoutils,
  lib,
  makeDesktopItem,
  p7zip,
  stdenvNoCC,
  symlinkJoin,
  util-linux,
  wineWow64Packages,
  writeShellApplication,
  xdg-utils,
}:

let
  pname = "evemon";
  version = "5.0.0-preview-3";
  installerVersion = "5.0.0";
  dotnetVersion = "8.0.22";
  wineGeckoVersion = "2.47.4";

  installer = fetchurl {
    url = "https://github.com/mgoeppner/evemon/releases/download/${version}/EVEMon-install-${installerVersion}.exe";
    hash = "sha256-rIKNutDdUwWCOSZ0R5ENb7eW3y2brE6b0viviJ8rjWs=";
  };

  # This release targets all three framework packs listed in
  # EVEMon.runtimeconfig.json. The desktop runtime includes Microsoft.NETCore.App;
  # ASP.NET Core is also needed for the local Kestrel server used during ESI SSO.
  desktopRuntime = fetchurl {
    url = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/${dotnetVersion}/windowsdesktop-runtime-${dotnetVersion}-win-x64.exe";
    hash = "sha512-ej9rVpIy6YGiKlJ+j4ak0BOlziIM0XM2QnDOzVbXqUw2Ji6yrxvVYSpqN/AuWVNe0zac+iNlXfRzGCJVCgo98w==";
  };

  aspnetRuntime = fetchurl {
    url = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/${dotnetVersion}/aspnetcore-runtime-${dotnetVersion}-win-x64.exe";
    hash = "sha512-eomY7emZ5Yt7BaHlVkM+ueA+rkheNmjVwIjMzmsQz/Qy/VO+InJdd2SeAqjv342jN+zHNxZoklpzdcv4cyVRJQ==";
  };

  # EVEMon uses a WinForms WebBrowser control to render EVE mail. Pin Wine's
  # matching 64-bit Gecko runtime so prefix setup can install it unattended.
  wineGecko = fetchurl {
    url = "https://dl.winehq.org/wine/wine-gecko/${wineGeckoVersion}/wine-gecko-${wineGeckoVersion}-x86_64.msi";
    hash = "sha256-5ZC32YijLWqkzx2Ko6o9M3Zv3Uz0yJwtzCCV7LKNBm8=";
  };

  evemon-unwrapped = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;
    src = installer;

    dontUnpack = true;

    nativeBuildInputs = [
      icoutils
      p7zip
    ];

    installPhase = ''
      runHook preInstall

      install -d "$out/share/evemon"
      7z x -y -o"$out/share/evemon" "$src"
      rm -rf "$out/share/evemon/\$PLUGINSDIR"
      rm -f "$out/share/evemon/uninstall.exe"

      # Build a freedesktop icon from the 128px image in the executable's
      # Windows icon group (resource index 1).
      wrestool \
        --extract \
        --type=14 \
        --name=1 \
        --output="$TMPDIR/evemon.ico" \
        "$out/share/evemon/EVEMon.exe"
      install -d "$TMPDIR/evemon-icons"
      icotool \
        --extract \
        --index=1 \
        --output="$TMPDIR/evemon-icons/evemon.png" \
        "$TMPDIR/evemon.ico"
      install -Dm644 "$TMPDIR/evemon-icons/evemon.png" \
        "$out/share/icons/hicolor/128x128/apps/${pname}.png"

      runHook postInstall
    '';
  };

  wine = wineWow64Packages.stable;

  launcher = writeShellApplication {
    name = pname;
    runtimeInputs = [
      coreutils
      util-linux
      xdg-utils
    ];
    text = ''
      umask 077

      show_help() {
        cat <<'EOF'
      Usage: evemon [--setup | --help] [EVEMon arguments...]

        --setup  Initialize the Wine prefix and install the required runtimes
        --help   Show this help

      Environment:
        EVEMON_DPI  UI scaling from 96 DPI (100%) to 480 DPI (500%; default: 144)
      EOF
      }

      setup_only=0
      case "''${1:-}" in
        --setup)
          setup_only=1
          shift
          ;;
        --help|-h)
          show_help
          exit 0
          ;;
      esac

      export WINEPREFIX="''${XDG_DATA_HOME:-$HOME/.local/share}/evemon/wineprefix"
      export WINEARCH=win64
      # Prevent Wine from creating desktop and menu entries outside this package.
      export WINEDLLOVERRIDES="''${WINEDLLOVERRIDES:+$WINEDLLOVERRIDES;}winemenubuilder.exe=d"

      evemon_dpi="''${EVEMON_DPI:-144}"
      if [[ ! "$evemon_dpi" =~ ^[1-9][0-9]{1,2}$ ]] || (( evemon_dpi < 96 || evemon_dpi > 480 )); then
        printf 'EVEMON_DPI must be an integer from 96 to 480.\n' >&2
        exit 2
      fi

      desktop_runtime_dir="$WINEPREFIX/drive_c/Program Files/dotnet/shared/Microsoft.WindowsDesktop.App/${dotnetVersion}"
      aspnet_runtime_dir="$WINEPREFIX/drive_c/Program Files/dotnet/shared/Microsoft.AspNetCore.App/${dotnetVersion}"
      gecko_runtime_dir="$WINEPREFIX/drive_c/windows/system32/gecko/${wineGeckoVersion}"
      gecko_runtime_file="$gecko_runtime_dir/wine_gecko/omni.ja"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/evemon"

      ensure_dotnet_runtime() {
        local label="$1"
        local runtime_dir="$2"
        local installer="$3"

        if [[ -d "$runtime_dir" ]]; then
          return
        fi

        printf 'Installing %s...\n' "$label"
        ${wine}/bin/wine "$installer" /install /quiet /norestart

        # A registered .NET bundle makes /install a no-op even when its
        # payload is damaged. Repair it if the expected runtime is still absent.
        if [[ ! -d "$runtime_dir" ]]; then
          printf 'Repairing incomplete %s...\n' "$label"
          ${wine}/bin/wine "$installer" /repair /quiet /norestart
        fi
      }

      mkdir -p "$WINEPREFIX" "$state_dir"
      exec 9>"$WINEPREFIX/.setup.lock"
      flock 9

      if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
        printf 'Initializing the EVEMon Wine prefix at %s\n' "$WINEPREFIX"
        # Wine Mono is not used by this native .NET 8 application, and Gecko is
        # installed explicitly below. Suppress only wineboot's interactive
        # runtime prompts; normal application DLL resolution remains enabled.
        WINEDLLOVERRIDES="$WINEDLLOVERRIDES;mscoree,mshtml=" \
          ${wine}/bin/wineboot --init

        # wineboot returns before the new registry is necessarily flushed to
        # disk. No application can be using a brand-new prefix, so wait here
        # to make the completed prefix visible to a concurrent launcher.
        ${wine}/bin/wineserver --wait
      fi

      if [[ ! -f "$gecko_runtime_file" ]]; then
        printf 'Installing Wine Gecko ${wineGeckoVersion} for EVEMon mail rendering...\n'
        ${wine}/bin/wine msiexec /i ${lib.escapeShellArg wineGecko} \
          /quiet /norestart
      fi

      ensure_dotnet_runtime \
        'Microsoft .NET Desktop Runtime ${dotnetVersion} for EVEMon' \
        "$desktop_runtime_dir" \
        ${lib.escapeShellArg desktopRuntime}

      ensure_dotnet_runtime \
        'Microsoft ASP.NET Core Runtime ${dotnetVersion} for EVEMon SSO' \
        "$aspnet_runtime_dir" \
        ${lib.escapeShellArg aspnetRuntime}

      if [[ ! -f "$gecko_runtime_file" || ! -d "$desktop_runtime_dir" || ! -d "$aspnet_runtime_dir" ]]; then
        printf 'EVEMon runtime setup did not complete successfully.\n' >&2
        exit 1
      fi

      # Wine uses 96 DPI as 100%. Update the prefix only when the requested
      # value differs so EVEMON_DPI can override the packaged 150% default.
      desired_dpi_hex="$(printf '0x%x' "$evemon_dpi")"
      current_dpi_hex=
      while read -r name type value; do
        if [[ "$name" == "LogPixels" && "$type" == "REG_DWORD" ]]; then
          current_dpi_hex="''${value%$'\r'}"
        fi
      done <<< "$(${wine}/bin/wine reg query 'HKEY_CURRENT_USER\Control Panel\Desktop' \
        /v LogPixels 2>/dev/null || true)"

      if [[ "$current_dpi_hex" != "$desired_dpi_hex" ]]; then
        ${wine}/bin/wine reg add 'HKEY_CURRENT_USER\Control Panel\Desktop' \
          /v LogPixels /t REG_DWORD /d "$evemon_dpi" /f >/dev/null
      fi

      flock --unlock 9
      exec 9>&-

      if (( setup_only )); then
        printf 'EVEMon runtime setup is complete.\n'
        exit 0
      fi

      # EVEMon writes crash_log.txt relative to its working directory. Keep
      # that state writable instead of pointing it at the immutable Nix store.
      cd "$state_dir"
      exec ${wine}/bin/wine \
        ${lib.escapeShellArg "${evemon-unwrapped}/share/evemon/EVEMon.exe"} \
        "$@"
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "EVEMon";
    genericName = "EVE Online Character Monitor";
    comment = "Monitor EVE Online characters and plan skill training";
    exec = "evemon";
    icon = pname;
    categories = [
      "Game"
      "Utility"
    ];
    keywords = [
      "EVE Online"
      "character"
      "skills"
    ];
    startupWMClass = "evemon.exe";
  };
in

symlinkJoin {
  name = "${pname}-${version}";
  paths = [
    evemon-unwrapped
    launcher
    desktopItem
  ];

  meta = {
    description = "EVE Online character monitor and skill planner";
    homepage = "https://github.com/mgoeppner/evemon";
    changelog = "https://github.com/mgoeppner/evemon/releases/tag/${version}";
    license = [
      lib.licenses.gpl2Only
      lib.licenses.mit
      lib.licenses.mpl20
    ];
    maintainers = [ lib.maintainers.h0lylag ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [
      lib.sourceTypes.binaryBytecode
      lib.sourceTypes.binaryNativeCode
    ];
  };
}
