{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  autoPatchelfHook,
  pkg-config,
  wrapGAppsHook3,
  nix-update-script,
  dbus,
  glib-networking,
  gsettings-desktop-schemas,
  gtk3,
  libGL,
  libx11,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrandr,
  wayland,
  webkitgtk_4_1,
}:

let
  runtimeLibs = [
    stdenv.cc.cc.lib
    libGL
    libxkbcommon
    wayland
    libx11
    libxcursor
    dbus
    gtk3
    glib-networking
    gsettings-desktop-schemas
    webkitgtk_4_1
    libxrandr
    libxi
  ];
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cmel";
  version = "0.0.4";

  src = fetchFromGitHub {
    owner = "Outback-Steakhouse-Of-Pancakes";
    repo = "Cormacks-Modified-EVE-Launcher";
    tag = "cmel-v${finalAttrs.version}";
    private = true;
    hash = "sha256-uNKqHFOx05xyVrgeQKA3guxIMJ6iMBzckweasoidO98=";
  };

  cargoHash = "sha256-Bi0QM4zPpRiQLBL85AzvX/1+PGcL5D143dVzdvWpO+E=";

  nativeBuildInputs = [
    pkg-config
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs;

  runtimeDependencies = runtimeLibs;

  postInstall = ''
    install -Dm644 assets/cmel.desktop $out/share/applications/cmel.desktop
    install -Dm644 assets/cmel.png $out/share/icons/hicolor/192x192/apps/cmel.png
    install -Dm644 assets/cmel.png $out/share/pixmaps/cmel.png
    install -Dm644 assets/cmel.metainfo.xml $out/share/metainfo/cmel.metainfo.xml
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Desktop launcher for EVE Online";
    homepage = "https://github.com/Outback-Steakhouse-Of-Pancakes/Cormacks-Modified-EVE-Launcher";
    changelog = "https://github.com/Outback-Steakhouse-Of-Pancakes/Cormacks-Modified-EVE-Launcher/releases/tag/cmel-v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ h0lylag ];
    platforms = lib.platforms.linux;
    mainProgram = "eve-launcher";
  };
})
