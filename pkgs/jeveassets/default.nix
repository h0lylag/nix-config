{
  stdenvNoCC,
  lib,
  fetchzip,
  fetchurl,
  makeWrapper,
  makeDesktopItem,
  jre,
  javaXms ? "512m",
  javaXmx ? "4g",
}:

stdenvNoCC.mkDerivation rec {
  pname = "jeveassets";
  version = "8.0.3";

  # 1) Upstream ZIP
  src = fetchzip {
    url = "https://github.com/GoldenGnu/jeveassets/releases/download/jeveassets-${version}/jeveassets-${version}.zip";
    sha256 = "dxVLvDrTLCtBrldJ/gyYTE8rXOOGNO2PGT61aCg9ZyI=";
  };

  # 2) Icon
  icon = fetchurl {
    url = "https://wiki.jeveassets.org/_media/wiki/logo.png";
    sha256 = "0y3828ssz7v3hw54099wdcfg66cv2jyb67qr1zbf5wxz16b5i264";
  };

  # Only need wrappers and desktop helpers at build time
  nativeBuildInputs = [ makeWrapper ];
  propagatedBuildInputs = [ jre ];

  # Skip all default phases except installPhase
  phases = [ "installPhase" ];

  installPhase = ''
    runHook preInstall

    # Copy already‑unpacked ZIP contents into $out/share
    mkdir -p $out/share/jeveassets
    cp -r "${src}/." "$out/share/jeveassets/"

    # Install icon
    install -Dm644 "${icon}" \
      "$out/share/icons/hicolor/64x64/apps/jeveassets.png"

    # Create launcher with sane defaults (override via JAVA_TOOL_OPTIONS)
    makeWrapper "${jre}/bin/java" "$out/bin/jeveassets" \
      --set-default JAVA_TOOL_OPTIONS "-Xms${javaXms} -Xmx${javaXmx}" \
      --add-flags "-jar $out/share/jeveassets/jeveassets.jar"

    runHook postInstall
  '';

  # Auto‑generate & install the .desktop file
  desktopItems = [
    (makeDesktopItem {
      name = "jeveassets";
      desktopName = "jEveAssets";
      comment = "EVE Online Asset Manager";
      exec = "jeveassets %U";
      icon = "jeveassets";
      categories = [ "Utility" ];
      terminal = false;
    })
  ];

  meta = with lib; {
    description = "jEveAssets — EVE Online Asset Manager";
    homepage = "https://github.com/GoldenGnu/jeveassets";
    license = licenses.gpl3Plus;
    maintainers = [ maintainers.h0lylag ];
    platforms = platforms.linux;

    # Indicate that we're shipping pre‑built Java bytecode
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
  };
}
