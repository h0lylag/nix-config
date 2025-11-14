{
  lib,
  pkgs,
  rustPlatform,
  fetchFromGitHub,
}:

let
  # Use musl64 cross-compilation for static linking
  cross = pkgs.pkgsCross.musl64;
in
cross.rustPlatform.buildRustPackage rec {
  pname = "eve-l-preview";
  version = "unstable";

  # Fetch from GitHub - use specific commit for reproducibility
  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/eve-l-preview.git";
    rev = "a05673af7cb7550bc589df5d49565aee84b4a8e2";
    allRefs = true;
  };

  # Cargo.lock hash - this will need to be updated based on the actual Cargo.lock
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  # Build as release with static linking
  buildType = "release";

  # Static linking flags
  RUSTFLAGS = "-C target-feature=+crt-static";

  nativeBuildInputs = [ cross.musl ];
  buildInputs = [ ];

  meta = with lib; {
    description = "EVE-L Preview - EVE Online window preview tool";
    homepage = "https://github.com/h0lylag/eve-l-preview";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "eve-l-preview";
  };
}
