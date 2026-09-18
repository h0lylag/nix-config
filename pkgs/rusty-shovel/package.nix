{
  lib,
  rustPlatform,
  makeWrapper,
  libGL,
  libxkbcommon,
  wayland,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
}:

let
  src = builtins.fetchGit {
    url = "ssh://git@github.com/Outback-Steakhouse-Of-Pancakes/rusty-shovel.git";
    rev = "246aa78d61bbced26c5dcb6d6de43aee8e1978d6";
  };

  runtimeLibraries = [
    libGL
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in

rustPlatform.buildRustPackage {
  pname = "rusty-shovel";
  version = "4.0.0";

  inherit src;
  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoBuildFlags = [
    "--bin"
    "shovel"
  ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    install -Dm644 assets/shovel.desktop $out/share/applications/shovel.desktop
    install -Dm644 assets/shovel-icon.png $out/share/icons/hicolor/128x128/apps/shovel.png
    install -Dm644 assets/shovel-icon.png $out/share/pixmaps/shovel.png
  '';

  postFixup = ''
    wrapProgram $out/bin/shovel --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibraries} --set RESOURCE_NAME shovel
  '';

  meta = {
    description = "EVE Online memory reader and scouting assistant";
    homepage = "https://github.com/Outback-Steakhouse-Of-Pancakes/rusty-shovel";
    changelog = "https://github.com/Outback-Steakhouse-Of-Pancakes/rusty-shovel/releases/tag/shovel-v4.0.0";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "shovel";
  };
}
