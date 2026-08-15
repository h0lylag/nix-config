{
  fetchurl,
  lib,
  makeWrapper,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tunarr";
  version = "1.3.13";

  src = fetchurl {
    url = "https://github.com/chrisbenincasa/tunarr/releases/download/v${finalAttrs.version}/tunarr-v${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-F3iHt11oN+IxPo80s/sMzuxCz+8muFbSPULnMpXmDkY=";
  };

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 tunarr-v${finalAttrs.version}-linux-x64 \
      "$out/lib/tunarr/tunarr"
    install -Dm755 meilisearch "$out/lib/tunarr/meilisearch"

    # Both release binaries must remain byte-for-byte intact.  In particular,
    # Tunarr is a Node `pkg` executable whose embedded VFS breaks if its ELF is
    # rewritten by patchelf or strip.

    # The release ELF keeps its /lib64 interpreter, so hosts need nix-ld. Tunarr
    # also stores absolute FFmpeg paths in writable settings; configure those
    # paths in the user or service configuration rather than relying on PATH.
    makeWrapper "$out/lib/tunarr/tunarr" "$out/bin/tunarr" \
      --set-default TUNARR_MEILISEARCH_PATH "$out/lib/tunarr/meilisearch" \
      --prefix NIX_LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          stdenv.cc.cc
          stdenv.cc.cc.libgcc
          stdenv.cc.libc
        ]
      }"

    runHook postInstall
  '';

  meta = {
    description = "Create live TV channels from media on Plex, Jellyfin, Emby, or local files";
    homepage = "https://tunarr.com/";
    changelog = "https://github.com/chrisbenincasa/tunarr/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      zlib
      mit
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "tunarr";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
