{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  autoPatchelfHook,
  pkg-config,
  nix-update-script,
  fontconfig,
  libGL,
  libxkbcommon,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  wayland,
}:

let
  runtimeLibs = [
    stdenv.cc.cc.lib
    libGL
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "eve-preview-manager";
  version = "1.7.0";

  src = fetchFromGitHub {
    owner = "h0lylag";
    repo = "EVE-Preview-Manager";
    tag = "v${finalAttrs.version}";
    hash = "sha256-uD3OoG7e9E7eY9QlFhqadDx/WtgBkgtwLQhERO3Hs24=";
  };

  cargoHash = "sha256-/u/f9682gKP8rWP3kPi5dcg+sE4JzgZfn7GlaJnEOyA=";

  nativeBuildInputs = [
    pkg-config
    autoPatchelfHook
  ];

  buildInputs = runtimeLibs ++ [ fontconfig ];

  runtimeDependencies = runtimeLibs;

  postInstall = ''
    install -Dm644 assets/com.evepreview.manager.desktop $out/share/applications/eve-preview-manager.desktop
    install -Dm644 assets/com.evepreview.manager.svg $out/share/icons/hicolor/scalable/apps/com.evepreview.manager.svg
    install -Dm644 assets/com.evepreview.manager.metainfo.xml $out/share/metainfo/com.evepreview.manager.metainfo.xml
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Utility for EVE Online multiboxing with real-time previews and hotkeys";
    homepage = "https://github.com/h0lylag/EVE-Preview-Manager";
    changelog = "https://github.com/h0lylag/EVE-Preview-Manager/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ h0lylag ];
    platforms = lib.platforms.linux;
    mainProgram = "eve-preview-manager";
  };
})
