{
  lib,
  pkgs,
  python3 ? pkgs.python312,
}:

let
  pname = "workshop-watcher";
  version = "0.1.0";
  src = pkgs.fetchFromGitHub {
    owner = "h0lylag";
    repo = "workshop-watcher";
    rev = "<commit-hash>"; # TODO pin
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # TODO update
  };
in
pkgs.stdenv.mkDerivation rec {
  inherit pname version src;

  nativeBuildInputs = [
    python3
    pkgs.makeWrapper
  ];

  installPhase = ''
        runHook preInstall

        mkdir -p $out/share/${pname}
        cp -r . $out/share/${pname}/

        mkdir -p $out/bin
        cat > $out/bin/${pname} <<EOF
    #!/usr/bin/env bash
    # Unbuffered for timely logs
    exec ${python3}/bin/python -u $out/share/${pname}/main.py "$@"
    EOF
        chmod +x $out/bin/${pname}

        runHook postInstall
  '';

  meta = with lib; {
    description = "Steam Workshop monitoring and Discord notification helper";
    homepage = "https://github.com/h0lylag/workshop-watcher";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
