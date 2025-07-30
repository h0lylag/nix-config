{
  stdenvNoCC,
  lib,
  fetchzip,
  fetchurl,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  jre,
  javaXms ? "512m",
  javaXmx ? "4g",
}:

stdenvNoCC.mkDerivation rec {
  pname = "jeveassets";
  version = "8.0.3";

  src = fetchzip {
    url = "https://github.com/GoldenGnu/jeveassets/releases/download/jeveassets-${version}/jeveassets-${version}.zip";
    sha256 = "dxVLvDrTLCtBrldJ/gyYTE8rXOOGNO2PGT61aCg9ZyI=";
  };

  icon = fetchurl {
    url = "https://wiki.jeveassets.org/_media/wiki/logo.png";
    sha256 = "0y3828ssz7v3hw54099wdcfg66cv2jyb67qr1zbf5wxz16b5i264";
  };

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ];

  propagatedBuildInputs = [ jre ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/jeveassets
    cp -r "${src}/." $out/share/jeveassets/

    install -Dm644 "${src}/license.txt" "$out/share/licenses/${pname}/LICENSE"
    install -Dm644 "${icon}"            "$out/share/icons/hicolor/64x64/apps/jeveassets.png"

    makeWrapper "${jre}/bin/java" "$out/bin/jeveassets" \
      --add-flags   "-Xms${javaXms}" \
      --add-flags   "-Xmx${javaXmx}" \
      --run 'if [ "$JEVE_HEADLESS" = "1" ] || [ "$JEVE_HEADLESS" = "true" ]; then export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -Djava.awt.headless=true"; fi' \
      --add-flags   "-jar $out/share/jeveassets/jeveassets.jar"

    runHook postInstall
  '';

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
    license = licenses.gpl2;
    maintainers = [ maintainers.h0lylag ];
    platforms = platforms.linux;
    sourceProvenance = [ sourceTypes.binaryBytecode ];
  };
}
