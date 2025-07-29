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

  phases = [ "installPhase" ];
  installPhase = ''
    runHook preInstall

    # unpack the upstream ZIP into share
    mkdir -p $out/share/jeveassets
    cp -r "${src}/." "$out/share/jeveassets/"

    # install the icon
    install -Dm644 "${icon}" "$out/share/icons/hicolor/64x64/apps/jeveassets.png"

    # wrap the java invocation with sane defaults (overridable via JEVE_JAVA_OPTS)
    makeWrapper "${jre}/bin/java" "$out/bin/jeveassets" \
      --set-default JEVE_JAVA_OPTS "-Xms${javaXms} -Xmx${javaXmx}" \
      --add-flags "-jar $out/share/jeveassets/jeveassets.jar"

    runHook postInstall
  '';

  # auto‑generate & install the .desktop file
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
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
  };
}
