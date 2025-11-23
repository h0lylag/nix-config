{
  lib,
  pkgs,
  rustPlatform ? pkgs.rustPlatform,
}:

let
  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/eve-l-preview.git";
    rev = "00880bbeb7e35ea9ac54f44f317c6be046e0a1cb";
    allRefs = true;
  };

  runtimeLibs = with pkgs; [
    libGL
    libxkbcommon
    wayland
    fontconfig
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
  ];
in
rustPlatform.buildRustPackage {
  pname = "eve-l-preview";
  version = "unstable";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";
  doCheck = false;

  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.pkg-config
  ];
  buildInputs = runtimeLibs;

  postInstall = ''
    wrapProgram $out/bin/eve-l-preview \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"
  '';

  CARGO_BUILD_JOBS = "30";

  meta = with lib; {
    description = "EVE-L Preview - EVE Online window preview tool";
    homepage = "https://github.com/h0lylag/eve-l-preview";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "eve-l-preview";
  };
}
