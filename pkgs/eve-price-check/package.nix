{
  lib,
  rustPlatform,
}:

let
  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/eve-price-check.git";
    ref = "main";
    # git ls-remote git@github.com:h0lylag/eve-price-check.git main
    rev = "83bda51fd28f929bf81a99f7e5aa5e1d9e566966";
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
