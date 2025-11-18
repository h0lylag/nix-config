{
  lib,
  pkgs,
  rustPlatform ? pkgs.rustPlatform,
}:

let
  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/eve-l-preview.git";
    rev = "b1e83a70413073b33418141cd0a7fac4458449ca";
    allRefs = true;
  };

  runtimeLibs = with pkgs; [
    libGL
    libxkbcommon
    wayland
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

  preBuild = ''
    export FONT_PATH="${pkgs.nerd-fonts.roboto-mono}/share/fonts/truetype/NerdFonts/RobotoMono/RobotoMonoNerdFont-Regular.ttf"
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
