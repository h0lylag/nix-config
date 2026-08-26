{
  lib,
  rustPlatform,
}:

let
  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/eve-price-check.git";
    ref = "main";
    rev = "e7c106ffd6f67e866b0f3bca987aef9226ff2945";
  };
in
rustPlatform.buildRustPackage {
  pname = "eve-price-checker";
  version = "0.1.0";

  inherit src;
  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoBuildFlags = [
    "--package"
    "eve-price-check"
  ];

  doCheck = false;

  meta = with lib; {
    description = "EVE Online appraisal service";
    homepage = "https://github.com/h0lylag/eve-price-check";
    platforms = platforms.linux;
    mainProgram = "eve-price-checker";
  };
}
