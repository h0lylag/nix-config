{
  lib,
  stdenv,
  fetchFromGitLab,
  gradle_9,
  jetbrains,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  unzip,
  alsa-lib,
  fontconfig,
  freetype,
  gfortran,
  gtk2-x11,
  gtk3,
  libappindicator-gtk3,
  libGL,
  libx11,
  libxcursor,
  libxext,
  libxi,
  libxinerama,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxt,
  libxtst,
  libxxf86vm,
  sndio,
  wayland,
  xdg-utils,
  zlib,
}:

let
  jdk = jetbrains.jdk;

  gradle = gradle_9.override {
    java = jdk;
    javaToolchains = [ jdk ];
  };

  runtimeLibs = [
    alsa-lib
    fontconfig
    freetype
    gfortran.cc.lib
    gtk2-x11
    gtk3
    libappindicator-gtk3
    libGL
    libxkbcommon
    libx11
    libxcursor
    libxext
    libxi
    libxinerama
    libxrandr
    libxrender
    libxt
    libxtst
    libxxf86vm
    sndio
    stdenv.cc.cc.lib
    wayland
    zlib
  ];
in

stdenv.mkDerivation (finalAttrs: {
  pname = "rift";
  version = "5.18.0";

  src = fetchFromGitLab {
    owner = "rift-intel-fusion-tool";
    repo = "rift-intel-fusion-tool";
    rev = "4579e968ed8801b9fa5f7d9def43e93f22ae021d";
    hash = "sha256-X+Qcmcc84djDWC7Viz8bP8uoZNQmcGwqHxqarrEc+J0=";
  };

  postPatch = ''
    substituteInPlace build.gradle.kts \
      --replace-fail 'buildConfigField("long", "buildTimestamp", "''${Instant.now().toEpochMilli()}")' \
                     'buildConfigField("long", "buildTimestamp", "0")'
  '';

  gradleBuildTask = "createDistributable";
  gradleUpdateTask = finalAttrs.gradleBuildTask;

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    inherit (finalAttrs) pname;
    data = ./deps.json;
    silent = false;
    useBwrap = false;
  };

  env.JAVA_HOME = jdk;

  gradleFlags = [
    "-Dorg.gradle.java.home=${jdk}"
    "-Prift.environment=prod"
    "-Prift.buildUuid=${finalAttrs.version}-nix"
    "--no-configuration-cache"
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    gradle
    jdk
    makeWrapper
    unzip
  ];

  buildInputs = runtimeLibs;
  runtimeDependencies = runtimeLibs;

  doCheck = false;
  dontStrip = true;

  desktopItems = [
    (makeDesktopItem {
      name = "rift";
      desktopName = "RIFT Intel Fusion Tool";
      comment = "Intel tool for EVE Online";
      exec = "rift %U";
      genericName = "EVE Online Tool";
      icon = "rift";
      categories = [ "Game" ];
      keywords = [
        "EVE Online"
        "intel"
        "fleet"
      ];
      startupWMClass = "dev-nohus-rift-MainKt";
      terminal = false;
    })
  ];

  installPhase = ''
    runHook preInstall

    appDir="$(find build/compose/binaries/main/app -mindepth 1 -maxdepth 1 -type d -print -quit)"
    if [ -z "$appDir" ]; then
      echo "Could not find Compose distributable" >&2
      find build/compose -maxdepth 5 -type d >&2 || true
      exit 1
    fi

    mkdir -p "$out"
    cp -R "$appDir/." "$out/"
    chmod -R u+w "$out"

    if [ -f "$out/bin/rift" ]; then
      :
    elif [ -f "$out/bin/RIFT" ]; then
      ln -s "$out/bin/RIFT" "$out/bin/rift"
    else
      launcher="$(find "$out/bin" -maxdepth 1 -type f -perm -0100 -print -quit)"
      if [ -n "$launcher" ]; then
        ln -s "$launcher" "$out/bin/rift"
      else
        echo "Could not find RIFT launcher in $out/bin" >&2
        exit 1
      fi
    fi

    for size in 32 44 64 128 150 256 512 1024; do
      iconFile="icon/Icon-$size.png"
      if [ -f "$iconFile" ]; then
        install -Dm644 "$iconFile" "$out/share/icons/hicolor/''${size}x''${size}/apps/rift.png"
      fi
    done

    # JavaCPP/JogAmp natives are loaded dynamically, so extract and patch the Linux ones.
    nativeLibDir="$out/lib/native"
    install -d "$nativeLibDir"
    for jar in \
      "$out"/lib/app/*linux*x86_64*.jar \
      "$out"/lib/app/*natives-linux-amd64*.jar \
      "$out"/lib/app/skiko-awt-runtime-linux-x64-*.jar; do
      [ -e "$jar" ] || continue
      nativeMembers="$(unzip -Z1 "$jar" | grep -E '\.so(\.[^/]+)?$' | grep -v '/python/' || true)"
      while read -r member; do
        [ -n "$member" ] || continue
        unzip -q -o -j "$jar" "$member" -d "$nativeLibDir"
      done <<< "$nativeMembers"
    done
    if [ -e "$nativeLibDir/libopenblas.so.0" ] && [ ! -e "$nativeLibDir/libopenblas_nolapack.so.0" ]; then
      ln -s libopenblas.so.0 "$nativeLibDir/libopenblas_nolapack.so.0"
    fi

    # Keep only native jars this x86_64-linux package can use.
    appCfg="$out/lib/app/rift.cfg"
    for jar in \
      "$out"/lib/app/*-android-*.jar \
      "$out"/lib/app/*-ios-*.jar \
      "$out"/lib/app/*-macosx-*.jar \
      "$out"/lib/app/*-windows-*.jar \
      "$out"/lib/app/*-linux-aarch64*.jar \
      "$out"/lib/app/*-linux-arm64*.jar \
      "$out"/lib/app/*-linux-armv6hf*.jar \
      "$out"/lib/app/*-linux-ppc64le*.jar; do
      [ -e "$jar" ] || continue
      jarName="$(basename "$jar")"
      rm -f "$jar"
      if [ -f "$appCfg" ]; then
        grep -Fvx "app.classpath=\$APPDIR/$jarName" "$appCfg" > "$appCfg.tmp"
        mv "$appCfg.tmp" "$appCfg"
      fi
    done

    runHook postInstall
  '';

  preFixup = ''
    for path in \
      "$out/lib/runtime/lib" \
      "$out/lib/runtime/lib/server" \
      "$out/lib/native"; do
      [ -d "$path" ] && addAutoPatchelfSearchPath "$path"
    done
  '';

  postFixup = ''
    wrapProgram "$out/bin/rift" \
      --prefix LD_LIBRARY_PATH : "$out/lib/native:${lib.makeLibraryPath runtimeLibs}" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}"
  '';

  meta = {
    description = "Intel fusion tool for EVE Online";
    homepage = "https://riftforeve.online/";
    downloadPage = "https://gitlab.com/rift-intel-fusion-tool/rift-intel-fusion-tool";
    license = lib.licenses.unfree;
    mainProgram = "rift";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
      binaryNativeCode
    ];
  };
})
