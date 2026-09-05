{
  lib,
  rustPlatform,
}:

let
  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/eve-price-check.git";
    ref = "main";
    # git ls-remote git@github.com:h0lylag/eve-price-check.git main
    rev = "8371f98a94ae12f943413f15d9c04b243f7850db";
  };
in
rustPlatform.buildRustPackage {
  pname = "eve-price-check";
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
    mainProgram = "eve-price-check";
  };
}
