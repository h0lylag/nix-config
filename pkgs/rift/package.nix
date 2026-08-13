{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
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

  # These are looked up by the bundled JVM and desktop integrations rather
  # than appearing as direct ELF dependencies.
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

  runtimeLibs = linkedRuntimeLibs ++ dynamicallyLoadedLibs;

  runtimePrograms = [
    # gdbus is Rift's preferred desktop notification backend.
    glib
    wmctrl
    xdg-utils
    xprop
    xwininfo
  ];
in

stdenv.mkDerivation (finalAttrs: {
  pname = "rift";
  version = "5.28.1";

  src = fetchurl {
    url = "https://riftforeve.online/download/rift-${finalAttrs.version}-linux-amd64.tar.gz";
    hash = "sha256-6ZZKTGF2k/8ZJpmR5vOH5u0yYbjrPXQrMQjA5a3+QqY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    stripJavaArchivesHook
    unzip
    zip
  ];

  buildInputs = runtimeLibs;
  runtimeDependencies = map lib.getLib dynamicallyLoadedLibs;

  strictDeps = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  # OpenCV depends on OpenBLAS from another jar. JavaCPP extracts both into its
  # shared cache, but autoPatchelf checks each temporary jar tree separately.
  autoPatchelfIgnoreMissingDeps = [ "libopenblas.so.0" ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R . "$out/"
    chmod -R u+w "$out"

    substituteInPlace "$out/share/applications/dev.nohus.rift.desktop" \
      --replace-fail 'Exec=/usr/lib/nohus/rift/bin/rift' "Exec=$out/bin/rift" \
      --replace-fail 'StartupWMClass=' 'StartupWMClass=dev-nohus-rift-MainKt'

    # Replace placeholder AppStream data shipped in the binary archive.
    metainfo="$out/share/metainfo/dev.nohus.rift.metainfo.xml"
    substituteInPlace "$metainfo" \
      --replace-fail \
        '<project_license>Proprietary</project_license>' \
        '<project_license>LicenseRef-proprietary</project_license>
        <url type="homepage">https://riftforeve.online/</url>' \
      --replace-fail \
        '    Intel tool for EVE Online' \
        '    RIFT combines EVE Online intel from multiple sources in one desktop application.'
    sed -i '/^    <releases>$/,/^    <\/releases>$/d' "$metainfo"

    # Several JVM dependencies unpack native libraries from their jars. Patch
    # their glibc x86_64 libraries in place. The OpenCV Python extension is not
    # used by this JVM application and is deliberately left untouched.
    addAutoPatchelfSearchPath "$out/lib/runtime/lib"
    addAutoPatchelfSearchPath "$out/lib/runtime/lib/server"

    # The bundled runtime needs fontconfig loaded before JVM initialization,
    # but the Conveyor launcher does not declare it. Make that dependency
    # explicit so Swing can initialize its font manager.
    patchelf --add-needed libfontconfig.so.1 "$out/bin/rift"

    nativeWork="$TMPDIR/rift-native-jars"
    mkdir -p "$nativeWork"
    for jar in "$out"/lib/app/*.jar; do
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

      # The no-LAPACK JNI shim expects an OpenBLAS variant that is not in the
      # archive. The bundled full library provides the required BLAS symbols.
      noLapackJni="$jarWork/org/bytedeco/openblas/linux-x86_64/libjniopenblas_nolapack.so"
      if [ -e "$noLapackJni" ]; then
        patchelf \
          --replace-needed libopenblas_nolapack.so.0 libopenblas.so.0 \
          "$noLapackJni"
      fi

      autoPatchelf -- "$jarWork"

      # Replace temporary and upstream build-machine RPATHs with $ORIGIN.
      # Libraries from a single native jar are extracted alongside each other.
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

    # Store paths inside jars are invisible to Nix's reference scanner. Follow
    # the nixpkgs convention of exposing the actual embedded references as
    # plain text so their runtime closure is retained.
    mkdir -p "$out/nix-support"
    find "$nativeWork" -type f -exec strings {} + \
      | { grep -F '${builtins.storeDir}/' || true; } \
      | sort -u > "$out/nix-support/depends"

    runHook postInstall
  '';

  preFixup = ''
    for path in \
      "$out/lib/runtime/lib" \
      "$out/lib/runtime/lib/server"; do
      [ -d "$path" ] && addAutoPatchelfSearchPath "$path"
    done
  '';

  postFixup = ''
    wrapProgram "$out/bin/rift" \
      --set FONTCONFIG_FILE "${fontconfig.out}/etc/fonts/fonts.conf" \
      --prefix PATH : "${lib.makeBinPath runtimePrograms}"
  '';

  meta = {
    description = "Intel fusion tool for EVE Online";
    homepage = "https://riftforeve.online/";
    downloadPage = "https://riftforeve.online/download.html";
    license = lib.licenses.unfree;
    mainProgram = "rift";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
  };
})
