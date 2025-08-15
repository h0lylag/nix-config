{
  lib,
  pkgs,
  python3 ? pkgs.python312,
}:

let
  pname = "workshop-watcher";
  version = "unstable"; # added version

  # Remote source
  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/workshop-watcher.git"; # SSH like diamond-boys
    rev = "7af695ddd9a6ce06d79d5473101f89be925d822e";
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

    cd $out/share/${pname}
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
