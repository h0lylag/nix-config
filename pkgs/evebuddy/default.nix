{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  pkg-config,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
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

  tags = [ "migrated_fynedo" ];

  nativeBuildInputs = [
    pkg-config
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = runtimeLibs;

  runtimeDependencies = runtimeLibs;

  # Fyne reads app metadata from a generated file that `fyne build` normally
  # creates. Since we use plain `go build` via buildGoModule, generate it ourselves.
  preBuild = ''
    cat > fyne_metadata_init.go <<GOEOF
package main

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
)

func init() {
	app.SetMetadata(fyne.AppMetadata{
		ID:      "io.github.erikkalkoken.evebuddy",
		Name:    "EVE Buddy",
		Version: "${finalAttrs.version}",
		Build:   1,
	})
}
GOEOF
  '';

  # UI golden-image tests require a display and fail in the sandbox
  doCheck = false;

  postInstall = ''
    install -Dm644 icon.png $out/share/icons/hicolor/128x128/apps/io.github.erikkalkoken.evebuddy.png
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "io.github.erikkalkoken.evebuddy";
      exec = "evebuddy";
      icon = "io.github.erikkalkoken.evebuddy";
      desktopName = "EVE Buddy";
      genericName = "Eve Online Tool";
      comment = finalAttrs.meta.description;
      categories = [ "Game" ];
      keywords = [ "Eve Online" "characters" ];
    })
  ];

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
