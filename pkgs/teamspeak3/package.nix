{
  lib,
  stdenv,
  fetchurl,
  fetchzip,
  makeDesktopItem,
  glib,
  qt5,
  libsForQt5,
  libcxx,
  autoPatchelfHook,
  copyDesktopItems,
  pkg-config,
  alsa-lib,
  pulseaudio,
  libxi,
  libx11,
}:
let
  pluginsdk = fetchzip {
    url = "https://files.teamspeak-services.com/releases/sdk/3.3.1/ts_sdk_3.3.1.zip";
    hash = "sha256-wx4pBZHpFPoNvEe4xYE80KnXGVda9XcX35ho4R8QxrQ=";
  };

  # Match the shared callback layout used inside the proprietary client.
  callbackHeader = fetchurl {
    url = "https://raw.githubusercontent.com/qt/qtwebengine/v5.15.2/src/core/api/qwebenginecallback.h";
    hash = "sha256-mkxfR0irDxCUlFv9fptb6RkXV54se741VQc4QmgdNkI=";
  };
in
stdenv.mkDerivation rec {
  pname = "teamspeak3";

  version = "3.6.2";

  src = fetchurl {
    url = "https://files.teamspeak-services.com/releases/client/${version}/TeamSpeak3-Client-linux_amd64-${version}.run";
    hash = "sha256-WfEQQ4lxoj+QSnAOfdCoEc+Z1Oa5dbo6pFli1DsAZCI=";
  };

  nativeBuildInputs = [
    pkg-config
    qt5.qtbase.dev
    qt5.wrapQtAppsHook
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    libsForQt5.quazip
    glib
    libcxx
    alsa-lib
    libxi
    libx11
  ]
  ++ (with qt5; [
    qtbase
    qtwebchannel
    qtwebsockets
    qtsvg
    qtimageformats
  ]);

  unpackPhase = ''
    runHook preUnpack

    sh "$src" --quiet --noexec --nox11 --accept
    cd TeamSpeak3-Client-linux_amd64

    runHook postUnpack
  '';

  patchPhase = ''
    runHook prePatch

    # Replace bundled system libraries and Qt plugins, but preserve TeamSpeak's
    # own ALSA backend: no nixpkgs library can replace that plugin.
    find . -maxdepth 1 \( -name '*.so' -o -name '*.so.*' \) -delete
    rm -r iconengines imageformats platforms sqldrivers xcbglintegrations
    rm -r QtWebEngineProcess resources qtwebengine_locales
    rm qt.conf ts3client_runscript.sh

    mv ts3client_linux_amd64 ts3client

    # Nixpkgs packages QuaZip under a different SONAME.
    patchelf --replace-needed libquazip.so libquazip1-qt5.so ts3client error_report

    runHook postPatch
  '';

  dontConfigure = true;
  strictDeps = true;

  buildPhase = ''
    runHook preBuild

    # Build local source copies outside the client tree copied during installation.
    mkdir -p "$NIX_BUILD_TOP/qtwebengine-stub"
    pushd "$NIX_BUILD_TOP/qtwebengine-stub"
    cp ${./qtwebengine-stub}/{stub.cpp,stub.h,version.map} .
    cp ${callbackHeader} qwebenginecallback.h
    # Only the module export/config header requires WebEngine itself.
    substituteInPlace qwebenginecallback.h \
      --replace-fail '#include <QtWebEngineCore/qtwebenginecoreglobal.h>' '#include <QtCore/qglobal.h>'
    moc stub.h -o moc_stub.cpp

    $CXX -std=c++17 -O2 -Wall -Wextra -Werror -fPIC -shared \
      -Wl,-z,defs -Wl,-soname,libQt5WebEngineWidgets.so.5 \
      -Wl,--version-script=version.map \
      -I. stub.cpp moc_stub.cpp -o libQt5WebEngineWidgets.so.5 \
      $(pkg-config --cflags --libs Qt5Widgets)

    # TS3 requires Core's SONAME but imports all WebEngine symbols from Widgets.
    $CXX -shared -Wl,-soname,libQt5WebEngineCore.so.5 \
      -x c++ /dev/null -o libQt5WebEngineCore.so.5
    popd

    runHook postBuild
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "teamspeak";
      exec = "ts3client %u";
      mimeTypes = [ "x-scheme-handler/ts3server" ];
      icon = "teamspeak";
      comment = "The TeamSpeak voice communication tool";
      desktopName = "TeamSpeak";
      genericName = "TeamSpeak";
      categories = [
        "Network"
        "Chat"
      ];
    })
  ];

  qtWrapperArgs = [
    # TS3's global hotkeys call X11 directly (XQueryKeymap). Preserve the
    # XWayland workaround even when the desktop exports QT_QPA_PLATFORM=wayland.
    "--set QT_QPA_PLATFORM xcb"
  ];
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/opt/teamspeak"
    cp -a . "$out/opt/teamspeak/"
    # autoPatchelf resolves TS3's WebEngine dependencies to these local libraries.
    install -m755 "$NIX_BUILD_TOP/qtwebengine-stub/"*.so.5 "$out/opt/teamspeak/"

    # The client installer omits a desktop icon; use the SDK's logo.
    install -Dm644 ${pluginsdk}/doc/_static/logo.png "$out/share/icons/hicolor/64x64/apps/teamspeak.png"

    mkdir -p "$out/bin"
    ln -s "$out/opt/teamspeak/ts3client" "$out/bin/ts3client"

    runHook postInstall
  '';

  # TS3 launches these helpers from its application directory. Wrap the actual
  # programs once so both internal launches and the bin symlink have Qt paths.
  postFixup = ''
    for program in ts3client error_report package_inst update; do
      wrapQtApp "$out/opt/teamspeak/$program" \
        --prefix LD_LIBRARY_PATH : "${
          lib.makeLibraryPath [
            pulseaudio
            alsa-lib
            libxi
            libx11
          ]
        }"
    done
  '';

  meta = {
    description = "TeamSpeak voice communication tool";
    homepage = "https://teamspeak.com/";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.teamspeak;
    maintainers = with lib.maintainers; [
      lhvwb
      lukegb
      atemu
    ];
    mainProgram = "ts3client";
    platforms = [ "x86_64-linux" ];
  };
}
