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
    rev = "7ead29722860a582ae5debb6912713bc00a02f37";
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
    SCRIPT_DIR="$(dirname "$0")/../share/${pname}"
    exec ${python3}/bin/python -u "$SCRIPT_DIR/main.py" "$@"
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
