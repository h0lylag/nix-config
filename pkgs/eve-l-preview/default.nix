{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  python3,
  qt5,
  wmctrl,
  xdotool,
  maim,
}:

let
  pythonEnv = python3.withPackages (
    ps: with ps; [
      pyqt5
      xlib
      keyboard
    ]
  );
in
stdenv.mkDerivation rec {
  pname = "eve-l-preview";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "h0lylag";
    repo = "EVE-L_Preview";
    rev = "main";
    hash = "sha256-5sDZJfJG2iKuyTlMaCzZ1+4Bu3EPudJVf8q7zV+Luo0=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    pythonEnv
    qt5.qtbase
    qt5.qtwayland
    qt5.qtimageformats
    wmctrl
    xdotool
    maim
  ];

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    # Create the installation directory
    mkdir -p $out/share/eve-l-preview
    mkdir -p $out/bin

    # Copy all the source files
    cp -r * $out/share/eve-l-preview/

    # Create the wrapper script
    makeWrapper ${pythonEnv}/bin/python $out/bin/eve-l-preview \
      --add-flags "$out/share/eve-l-preview/main.py" \
      --prefix PATH : ${
        lib.makeBinPath [
          wmctrl
          xdotool
          maim
        ]
      } \
      --set QT_PLUGIN_PATH "${qt5.qtbase}/lib/qt-${qt5.qtbase.version}/plugins:${qt5.qtimageformats}/lib/qt-${qt5.qtbase.version}/plugins" \
      --set QT_QPA_PLATFORM "xcb" \
      --set XDG_SESSION_TYPE "x11" \
      --set QT_AUTO_SCREEN_SCALE_FACTOR "0" \
      --set QT_SCREEN_SCALE_FACTORS "" \
      --set-default DISPLAY ":0"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Quick and dirty EVE-O Preview implementation for Linux systems";
    homepage = "https://github.com/h0lylag/EVE-L_Preview";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "eve-l-preview";
  };
}
