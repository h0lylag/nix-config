{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  nss,
  nspr,
  gtk3,
  at-spi2-core,
  at-spi2-atk,
  libXScrnSaver,
  libXtst,
  libappindicator-gtk3,
  libnotify,
  libuuid,
  libsecret,
  alsa-lib,
  cups,
  dbus,
  expat,
  glib,
  pango,
  cairo,
  gdk-pixbuf,
  xorg,
  libxkbcommon,
  udev,
  mesa,
  systemdLibs,
  gsettings-desktop-schemas,
}:

let
  pname = "command-code";
  version = "0.1.13";

  src = fetchurl {
    url = "https://github.com/CommandCodeAI/desktop/releases/download/v${version}/CommandCode-${version}-amd64.deb";
    sha256 = "sha256-ExT4UrkLCyNn7EEhcBt2vaA06uRSr4MwPU7M5OuUluo=";
  };

  desktopItem = makeDesktopItem {
    name = "command-code";
    desktopName = "Command Code";
    exec = "command-code %U";
    icon = "command-code";
    comment = "Command Code desktop app";
    categories = [ "Development" ];
    mimeTypes = [ "x-scheme-handler/commandcode" ];
    startupWMClass = "command-code";
  };
in
stdenv.mkDerivation {
  inherit pname version;

  src = src;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    nss
    nspr
    gtk3
    at-spi2-core
    at-spi2-atk
    libXScrnSaver
    libXtst
    libappindicator-gtk3
    libnotify
    libuuid
    libsecret
    alsa-lib
    cups
    dbus
    expat
    glib
    pango
    cairo
    gdk-pixbuf
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    libxkbcommon
    udev
    mesa
    systemdLibs
    gsettings-desktop-schemas
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" "$out-tmp"
    runHook postUnpack
  '';

  # The deb installs to /opt/Command Code/ with spaces; keep the layout so the
  # app's self-references and electron-updater expectations keep working.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec"
    cp -r "$out-tmp/opt/Command Code" "$out/libexec/Command Code"
    chmod -R u+w "$out/libexec/Command Code"

    # Desktop integration: icons + desktop entry
    mkdir -p "$out/share/icons"
    cp -r "$out-tmp/usr/share/icons/hicolor" "$out/share/icons/"
    mkdir -p "$out/share/applications"

    install -Dm644 "$out-tmp/usr/share/applications/command-code.desktop" \
      "$out/share/applications/command-code.desktop"

    # Main binary
    mkdir -p "$out/bin"
    ln -s "$out/libexec/Command Code/command-code" "$out/bin/command-code"

    runHook postInstall
  '';

  preFixup = ''
    # NOTE: the deb's postinst normally chmods chrome-sandbox to 4755 (setuid).
    # That's not possible in the Nix store, and Electron's sandbox uses
    # user namespaces on NixOS; leave it as-is (the app falls back gracefully).
  '';

  dontStrip = true;

  # The npm bundles both glibc and musl prebuilds for some native modules
  # (e.g. @parcel/watcher). autoPatchelf scans all of them; the musl ones are
  # never used on NixOS, so ignore their missing deps.
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
  ];

  # chromium/electron ships a bundled copy; no need to patch them.
  # autoPatchelf will patch the main binary against our buildInputs.
  postFixup = ''
    # desktop entry from the deb references /opt/Command Code/command-code;
    # rewrite to our store path via the wrapper.
    substituteInPlace "$out/share/applications/command-code.desktop" \
      --replace '/opt/Command Code/command-code' 'command-code'
  '';

  desktopItems = [ desktopItem ];

  meta = {
    description = "Command Code desktop app";
    homepage = "https://commandcode.ai";
    changelog = "https://github.com/CommandCodeAI/desktop/releases/tag/v${version}";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "command-code";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
