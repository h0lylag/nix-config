{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  pkg-config,
  autoPatchelfHook,
  libGL,
  libX11,
  libXcursor,
  libXrandr,
  libXinerama,
  libXi,
  libXxf86vm,
  wayland,
  libxkbcommon,
  stdenv,
}:

let
  runtimeLibs = [
    stdenv.cc.cc.lib
    libGL
    libX11
    libXcursor
    libXrandr
    libXinerama
    libXi
    libXxf86vm
    wayland
    libxkbcommon
  ];
in

buildGoModule (finalAttrs: {
  pname = "evebuddy";
  version = "0.64.0";

  src = fetchFromGitHub {
    owner = "ErikKalkoken";
    repo = "evebuddy";
    tag = "v${finalAttrs.version}";
    hash = "sha256-qtUhvu0m/+vD9cUbMSldrBfM0Qc2WE715k2NJeI+w5Q=";
  };

  vendorHash = "sha256-mO2KULDcU3OOd5a4P7jrmjYIDaKn+hIS+A36wgwxEYE=";

  subPackages = [ "." ];

  nativeBuildInputs = [
    pkg-config
    autoPatchelfHook
  ];

  buildInputs = runtimeLibs;

  runtimeDependencies = runtimeLibs;

  # UI golden-image tests require a display and fail in the sandbox
  doCheck = false;

  postInstall = ''
        install -Dm644 icon.png $out/share/icons/hicolor/128x128/apps/io.github.erikkalkoken.evebuddy.png

        mkdir -p $out/share/applications
        cat > $out/share/applications/io.github.erikkalkoken.evebuddy.desktop <<'EOF'
    [Desktop Entry]
    Type=Application
    Name=EVE Buddy
    GenericName=Eve Online Tool
    Exec=evebuddy
    Icon=io.github.erikkalkoken.evebuddy
    Comment=A multi-platform companion app for Eve Online players
    Categories=Game;
    Keywords=Eve Online;characters;
    EOF
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "A companion app for Eve Online players";
    homepage = "https://github.com/ErikKalkoken/evebuddy";
    changelog = "https://github.com/ErikKalkoken/evebuddy/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "evebuddy";
  };
})
