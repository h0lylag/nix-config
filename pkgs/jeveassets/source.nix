{
  lib,
  stdenv,
  fetchFromGitHub,
  jdk8,
  maven,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
}:

stdenv.mkDerivation rec {
  pname = "jeveassets";
  version = "8.0.3";

  src = fetchFromGitHub {
    owner = "GoldenGnu";
    repo = "jeveassets";
    rev = "v${version}";
    sha256 = lib.fakeSha256; # You'll need to update this after first build attempt
  };

  nativeBuildInputs = [
    jdk8
    maven
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = [
    jdk8
  ];

  # Use Maven to build the project as intended
  buildPhase = ''
    runHook preBuild

    echo "Building jEveAssets using Maven..."

    # Use Maven to compile and package the project
    # The pom.xml defines all dependencies and build configuration
    mvn compile package -Dmaven.test.skip=true -Dskip-online-tests=true

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install the compiled JAR and dependencies
    mkdir -p $out/bin $out/share/jeveassets $out/share/doc/jeveassets

    # Copy the main JAR
    if [ -f target/jeveassets.jar ]; then
      cp target/jeveassets.jar $out/share/jeveassets/
    else
      echo "Error: Main JAR not found at target/jeveassets.jar"
      ls -la target/
      exit 1
    fi

    # Copy dependency JARs
    if [ -d target/lib ]; then
      cp -r target/lib $out/share/jeveassets/
    fi

    # Copy data files
    if [ -d target/data ]; then
      cp -r target/data $out/share/jeveassets/
    fi

    # Create executable wrapper
    makeWrapper ${jdk8}/bin/java $out/bin/jeveassets \
      --add-flags "-jar $out/share/jeveassets/jeveassets.jar" \
      --add-flags "-Djava.library.path=$out/share/jeveassets/lib"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "jeveassets";
      exec = "jeveassets";
      icon = "jeveassets";
      desktopName = "jEveAssets";
      comment = "EVE Online asset management tool";
      categories = [
        "Game"
        "Utility"
      ];
    })
  ];

  meta = with lib; {
    description = "EVE Online asset management tool (source build)";
    longDescription = ''
      jEveAssets is an out-of-game asset manager for EVE Online, written in Java.

      This source-based build compiles jEveAssets from GitHub source using Maven.
      The project includes comprehensive dependencies defined in pom.xml including:
      - EVE ESI API integration
      - Pricing and routing data
      - SQLite database support
      - Swing GUI with FlatLaf look and feel
      - Various data processing libraries

      Build may require network access to download Maven dependencies.
    '';
    homepage = "https://wiki.jeveassets.org/";
    downloadPage = "https://github.com/GoldenGnu/jeveassets/releases";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
    sourceProvenance = with sourceTypes; [ fromSource ];
    # Note: This may fail during build due to network dependency downloads
    # Use binary.nix for a guaranteed working version
  };
}
