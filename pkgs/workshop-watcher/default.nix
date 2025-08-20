{
  lib,
  pkgs,
  python3,
}:

let
  pname = "workshop-watcher";
  version = "unstable";

  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/workshop-watcher.git";
    rev = "d9063727dd5d75168be9074e7c5d0e95ec67551e";
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

        cat > $out/bin/${pname} <<'EOF'
    #!/usr/bin/env bash
    cd "$(dirname "$0")/../share/${pname}" || exit 1
    exec ${python3}/bin/python -u main.py "$@"
    EOF
        chmod +x $out/bin/${pname}

        runHook postInstall
  '';

  meta = with lib; {
    description = "Steam Workshop monitoring and Discord notification tool";
    homepage = "https://github.com/h0lylag/workshop-watcher";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
