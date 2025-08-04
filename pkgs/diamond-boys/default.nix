{
  lib,
  pkgs,
  python3,
  zkillQueueId ? "diamond_rats_1eHasdsd4Pd3Fj",
}:

let
  # Fetch the SDE file - we need the hash for pure evaluation mode
  sdeFile = builtins.fetchurl {
    url = "https://www.fuzzwork.co.uk/dump/sqlite-latest.sqlite.bz2";
    sha256 = "0rriqw6wid89wpkslcdkm1wi6vqfjkf0fmqv4nn1aca0fmwyg9cm";
  };
in

pkgs.stdenv.mkDerivation rec {
  pname = "diamond-boys";
  version = "unstable";

  # Source configuration - switch between local and remote as needed
  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/diamond-boys.git";
    rev = "0831f3b29059bd1d439a82ce74f015ac627308a2"; # Pin to specific commit for pure evaluation mode
  };

  nativeBuildInputs = [
    python3
    pkgs.bzip2
  ];

  buildPhase = ''
    runHook preBuild

    # Extract the pre-downloaded SDE file
    echo "Extracting SDE file..."
    cp ${sdeFile} sqlite-latest.sqlite.bz2
    bzip2 -d sqlite-latest.sqlite.bz2
    mv sqlite-latest.sqlite SDE-$(date +%Y%m%d).sqlite

    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall

        # Install application files
        mkdir -p $out/bin $out/share/diamond-boys
        cp -r * $out/share/diamond-boys/

        # Patch configuration values using substituteInPlace (the Nix way)
        substituteInPlace $out/share/diamond-boys/diamond-boys.py \
          --replace 'ZKILL_QUEUE_ID = "diamond_rats_1eHasdsd4Pd3Fj"' \
                    'ZKILL_QUEUE_ID = "${zkillQueueId}"' \
          --replace 'SQLITE_DB_FILE = get_sde_sqlite()' \
                    "SQLITE_DB_FILE = \"$out/share/diamond-boys/SDE-$(date +%Y%m%d).sqlite\""

        # Create launcher script with directory setup
        cat > $out/bin/diamond-boys << EOF
    #!/usr/bin/env bash

    cd $out/share/diamond-boys
    exec ${python3}/bin/python diamond-boys.py "\$@"
    EOF

        chmod +x $out/bin/diamond-boys
        runHook postInstall
  '';

  meta = with lib; {
    description = "Diamond Boys - EVE Online Diamond Rat Kill Tracker";
    homepage = "https://github.com/h0lylag/diamond-boys";
    platforms = platforms.linux;
    mainProgram = "diamond-boys";
  };
}
