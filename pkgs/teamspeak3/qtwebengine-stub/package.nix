{ pkgs }:
pkgs.stdenv.mkDerivation {
  name = "qtwebengine-stub";

  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.qt5.qtbase ];

  # Skip unpacking entirely, we will reference the files directly
  dontUnpack = true;
  dontWrapQtApps = true;

  # Notice how we use ${./version.map} and ${./stub.cpp} directly in the command.
  # Nix will replace these with the exact paths to the files in the Nix store!
  buildPhase = ''
    g++ -shared -fPIC -Wl,--version-script=${./version.map} -o libQt5WebEngineCore.so.5 ${./stub.cpp} $(pkg-config --cflags --libs Qt5Widgets Qt5Core)
    g++ -shared -fPIC -Wl,--version-script=${./version.map} -o libQt5WebEngineWidgets.so.5 ${./stub.cpp} $(pkg-config --cflags --libs Qt5Widgets Qt5Core)
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp *.so.* $out/lib/
  '';
}
