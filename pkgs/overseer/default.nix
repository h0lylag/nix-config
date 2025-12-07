{
  lib,
  pkgs,
  # Choose Python version; default to python3 from the current channel
  python3 ? pkgs.python3,
}:

let
  python = python3;

  # discord.py pinned to 2.6.4
  discordPy = python.pkgs.buildPythonPackage rec {
    pname = "discord.py";
    version = "2.6.4";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/ce/e7/9b1dbb9b2fc07616132a526c05af23cfd420381793968a189ee08e12e35f/discord_py-2.6.4.tar.gz";
      sha256 = "sha256-RDhJILrpt6Bz32SumxTIz4X5J0ta1dHQe9WmdTneLak=";
    };

    pyproject = true;
    build-system = with python.pkgs; [ setuptools ];
    propagatedBuildInputs = with python.pkgs; [
      aiohttp
      yarl
      audioop-lts
    ];
    doCheck = false;

    meta = with lib; {
      description = "A Python wrapper for the Discord API";
      homepage = "https://github.com/Rapptz/discord.py";
      license = licenses.mit;
    };
  };

  # discord-protos 0.0.2 as used previously
  discordProtos = python.pkgs.buildPythonPackage rec {
    pname = "discord-protos";
    version = "0.0.2";

    src = pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-I5U6BfMr7ttAtwjsS0V1MKYZaknI110zeukoKipByZc=";
    };

    pyproject = true;
    build-system = with python.pkgs; [ setuptools ];
    propagatedBuildInputs = with python.pkgs; [ protobuf ];

    doCheck = false;
    pythonImportsCheck = [ "discord_protos" ];

    meta = with lib; {
      description = "Discord protocol buffers for Python";
      homepage = "https://pypi.org/project/discord-protos/";
      license = licenses.mit;
    };
  };

  # Python environment with all Overseer dependencies
  pythonEnv = python.withPackages (
    ps: with ps; [
      requests
      yarl
      aiohttp
      protobuf
      sqlalchemy
      psycopg2
      numpy
      scipy
      joblib
      discordPy
      discordProtos
    ]
  );
in
pkgs.stdenv.mkDerivation rec {
  pname = "overseer";
  version = "unstable";

  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/Overseer.git";
    rev = "2e25d33b20f26a016bb1e43ceb7e61a67f5f4697";
  };

  nativeBuildInputs = [ pythonEnv ];

  installPhase = ''
    runHook preInstall

    # Install application files
    mkdir -p $out/bin $out/share/overseer
    cp -r * $out/share/overseer/

    # Create launcher script robustly (no heredoc expansion issues)
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      'cd '"$out"'/share/overseer' \
      'exec '"${pythonEnv}"'/bin/python main.py "$@"' \
      > "$out/bin/overseer"

    chmod +x "$out/bin/overseer"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Overseer Discord Bot";
    homepage = "https://github.com/h0lylag/overseer";
    platforms = platforms.linux;
    mainProgram = "overseer";
  };
}
