{
  lib,
  pkgs,
  # Choose Python version; default to python3 from the current channel
  python3 ? pkgs.python3,
  # Provide your source when calling this package, e.g.:
  # pkgs.callPackage ./pkgs/overseer { src = builtins.fetchGit { url = "git@github.com:h0lylag/overseer.git"; rev = "<commit>"; }; }
  # Default to pinned upstream repo; override if needed when calling this package
  src ? builtins.fetchGit {
    url = "git@github.com:h0lylag/Overseer.git";
    rev = "d0e0f35e90eb31f8b03f9cf29c92a4d5553e0836";
  },
}:

let
  python = python3;

  # discord.py pinned to 2.5.2, matching the original flake
  discordPy = python.pkgs.buildPythonPackage rec {
    pname = "discord.py";
    version = "2.5.2";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/7f/dd/5817c7af5e614e45cdf38cbf6c3f4597590c442822a648121a34dee7fa0f/discord_py-2.5.2.tar.gz";
      sha256 = "sha256-Ac02ICO/6hpKHUP1KAte8AytLH66gAmJCfmL8o5XhSQ=";
    };

    pyproject = true;
    build-system = with python.pkgs; [ setuptools ];
    propagatedBuildInputs = with python.pkgs; [
      aiohttp
      yarl
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

  inherit src;

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
