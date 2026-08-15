{
  lib,
  stdenv,
  fetchFromGitLab,
  gradle_9,
  jetbrains,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  makeWrapper,
  stripJavaArchivesHook,
  unzip,
  zip,
  alsa-lib,
  dbus,
  fontconfig,
  freetype,
  gfortran,
  glib,
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
  systemd,
  wayland,
  wmctrl,
  xdg-utils,
  xprop,
  xwininfo,
  zlib,
}:

let
  linkedRuntimeLibs = [
    alsa-lib
    dbus
    fontconfig
    freetype
    gfortran.cc.lib
    gtk2-x11
    libGL
    libx11
    libxext
    libxi
    libxrender
    libxtst
    sndio
    stdenv.cc.cc.lib
    systemd
    wayland
    zlib
  ];

  dynamicallyLoadedLibs = [
    gtk3
    libappindicator-gtk3
    libxcursor
    libxinerama
    libxkbcommon
    libxrandr
    libxt
    libxxf86vm
  ];

  runtimePrograms = [
    glib
    wmctrl
    xdg-utils
    xprop
    xwininfo
  ];
in

stdenv.mkDerivation (finalAttrs: {
  pname = "rift-git";
  version = "5.18.0-unstable-2026-04-12";

  src = fetchFromGitLab {
    owner = "rift-intel-fusion-tool";
    repo = "rift-intel-fusion-tool";
    rev = "4579e968ed8801b9fa5f7d9def43e93f22ae021d";
    hash = "sha256-X+Qcmcc84djDWC7Viz8bP8uoZNQmcGwqHxqarrEc+J0=";
  };

  postPatch = ''
    substituteInPlace build.gradle.kts \
      --replace-fail 'Instant.now().toEpochMilli()' '1776024967000'
  '';

  # Upstream's ProGuard 7.7 release task does not support Java 25 bytecode.
  gradleBuildTask = "createDistributable";
  gradleUpdateTask = finalAttrs.gradleBuildTask;

  mitmCache = gradle_9.fetchDeps {
    inherit (finalAttrs) pname;
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
  };

  env.JAVA_HOME = jetbrains.jdk;

  gradleFlags = [
    "-Dorg.gradle.java.home=${jetbrains.jdk}"
    "-Prift.environment=prod"
    "-Prift.buildUuid=${finalAttrs.src.rev}"
  ];

  nativeBuildInputs = [
    gradle_9
    jetbrains.jdk
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
    stripJavaArchivesHook
    unzip
    zip
  ];

  buildInputs = linkedRuntimeLibs ++ dynamicallyLoadedLibs;
  runtimeDependencies = map lib.getLib dynamicallyLoadedLibs;

  strictDeps = true;

  # OpenCV depends on OpenBLAS from another jar. JavaCPP extracts both into its
  # shared cache, but autoPatchelf checks each temporary jar tree separately.
  autoPatchelfIgnoreMissingDeps = [ "libopenblas.so.0" ];

  # Fifteen upstream tokenization tests fail at this revision.
  doCheck = false;

  desktopItems = [
    (makeDesktopItem {
      name = "dev.nohus.rift";
      desktopName = "RIFT Intel Fusion Tool";
      comment = "Intel tool for EVE Online";
      exec = "rift";
      icon = "dev.nohus.rift";
      categories = [ "Game" ];
      startupWMClass = "dev-nohus-rift-MainKt";
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/rift"
    cp -R build/compose/binaries/main/app/rift/lib/app "$out/share/rift/lib"
    install -Dm644 icon/Icon-512.png \
      "$out/share/icons/hicolor/512x512/apps/dev.nohus.rift.png"

    # The JavaCPP platform dependency includes native jars for every target.
    # This package only supports x86_64-linux, so omit the other classifiers.
    find "$out/share/rift/lib" -maxdepth 1 -type f \
      \( -name '*-android-*.jar' \
      -o -name '*-ios-*.jar' \
      -o -name '*-macos-*.jar' \
      -o -name '*-macosx-*.jar' \
      -o -name '*-windows-*.jar' \
      -o -name '*-linux-aarch64-*.jar' \
      -o -name '*-linux-arm64-*.jar' \
      -o -name '*-linux-armv6hf-*.jar' \) \
      -delete

    addAutoPatchelfSearchPath "${jetbrains.jdk}/lib/openjdk/lib"
    addAutoPatchelfSearchPath "${jetbrains.jdk}/lib/openjdk/lib/server"

    # JavaCPP and the audio libraries unpack native code from their jars.
    # Patch the Linux x86_64 libraries before they reach the runtime cache.
    nativeWork="$TMPDIR/rift-native-jars"
    mkdir -p "$nativeWork"
    for jar in "$out"/share/rift/lib/*.jar; do
      mapfile -t nativeMembers < <(
        unzip -Z1 "$jar" \
          | grep -Ei '(^|/)(linux[-_/](x86[-_]?64|x64|amd64)|Linux/(x86_64|amd64))(/|$)|(^|/)lib[^/]*linux[-_](x86[-_]?64|x64|amd64)\.so' \
          | grep -E '\.so(\.[0-9]+)*$' \
          | grep -v '/python/' \
          || true
      )
      (( ''${#nativeMembers[@]} > 0 )) || continue

      jarWork="$nativeWork/$(basename "$jar" .jar)"
      mkdir -p "$jarWork"
      unzip -q "$jar" "''${nativeMembers[@]}" -d "$jarWork"

      noLapackJni="$jarWork/org/bytedeco/openblas/linux-x86_64/libjniopenblas_nolapack.so"
      if [ -e "$noLapackJni" ]; then
        patchelf \
          --replace-needed libopenblas_nolapack.so.0 libopenblas.so.0 \
          "$noLapackJni"
      fi

      autoPatchelf -- "$jarWork"

      # Extracted libraries from one jar live together, so keep $ORIGIN plus
      # any Nix store paths added by autoPatchelf and discard build paths.
      while IFS= read -r elf; do
        oldRpath="$(patchelf --print-rpath "$elf")"
        newRpath=
        IFS=: read -ra rpathEntries <<< "$oldRpath"
        for entry in "''${rpathEntries[@]}"; do
          case "$entry" in
            "$jarWork"/*)
              entry='$ORIGIN'
              ;;
            '$ORIGIN'|'$ORIGIN'/*|${builtins.storeDir}/*)
              ;;
            *)
              continue
              ;;
          esac
          case ":$newRpath:" in
            *":$entry:"*) ;;
            *) newRpath="''${newRpath:+$newRpath:}$entry" ;;
          esac
        done
        case ":$newRpath:" in
          *':$ORIGIN:'*) ;;
          *) newRpath="''${newRpath:+$newRpath:}"'$ORIGIN' ;;
        esac
        patchelf --set-rpath "$newRpath" "$elf"
      done < <(find "$jarWork" -type f -exec file {} + | sed -n 's/:.*ELF.*//p')

      # Skiko verifies its native library against this bundled checksum.
      skikoChecksum=libskiko-linux-x64.so.sha256
      if unzip -Z1 "$jar" | grep -Fxq "$skikoChecksum"; then
        unzip -q "$jar" "$skikoChecksum" -d "$jarWork"
        sha256sum "$jarWork/libskiko-linux-x64.so" \
          | cut -d ' ' -f 1 > "$jarWork/$skikoChecksum"
        nativeMembers+=("$skikoChecksum")
      fi

      (cd "$jarWork" && zip -q -u "$jar" "''${nativeMembers[@]}")
    done

    # Store paths inside jars are invisible to Nix's reference scanner.
    mkdir -p "$out/nix-support"
    find "$nativeWork" -type f -exec strings {} + \
      | { grep -F '${builtins.storeDir}/' || true; } \
      | sort -u > "$out/nix-support/depends"

    makeWrapper ${jetbrains.jdk}/bin/java "$out/bin/rift" \
      --add-flags "--add-opens=java.desktop/java.awt=ALL-UNNAMED" \
      --add-flags "--add-exports=java.desktop/java.awt.peer=ALL-UNNAMED" \
      --add-flags "--enable-native-access=ALL-UNNAMED" \
      --add-flags "-cp \"$out/share/rift/lib:$out/share/rift/lib/*\"" \
      --add-flags "dev.nohus.rift.MainKt" \
      --set FONTCONFIG_FILE "${fontconfig.out}/etc/fonts/fonts.conf" \
      --prefix PATH : "${lib.makeBinPath runtimePrograms}"

    runHook postInstall
  '';

  preFixup = ''
    riftPostFixup() {
      sha256sum "$out/share/rift/lib/libskiko-linux-x64.so" \
        | cut -d ' ' -f 1 > "$out/share/rift/lib/libskiko-linux-x64.so.sha256"
    }
    postFixupHooks+=(riftPostFixup)
  '';

  meta = {
    description = "Intel fusion tool for EVE Online, built from source";
    homepage = "https://gitlab.com/rift-intel-fusion-tool/rift-intel-fusion-tool";
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
