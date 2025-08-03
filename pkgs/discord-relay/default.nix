{
  lib,
  pkgs,
  python312,
}:

let
  python = python312;

  discordPySelf = python.pkgs.buildPythonPackage rec {
    pname = "discord.py-self";
    version = "2.0.1";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/source/d/discord-py-self/discord_py_self-${version}.tar.gz";
      sha256 = "sha256-nGVUlTR3LWOxszQJw7tMKHN6lhVyf8Bbip8WHE47rX0=";
    };

    pyproject = true;
    build-system = with python.pkgs; [ setuptools ];

    propagatedBuildInputs = with python.pkgs; [
      aiohttp
      yarl
      discordProtos
    ];

    doCheck = false;
    # Disable import check due to audioop module removal in Python 3.13
    # pythonImportsCheck = [ "discord" ];

    meta = with lib; {
      description = "A Python wrapper for the Discord user API";
      homepage = "https://github.com/dolfies/discord.py-self";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
    };
  };

  discordProtos = python.pkgs.buildPythonPackage rec {
    pname = "discord-protos";
    version = "0.0.2";

    src = pkgs.fetchPypi {
      pname = "discord-protos";
      version = "0.0.2";
      sha256 = "sha256-I5U6BfMr7ttAtwjsS0V1MKYZaknI110zeukoKipByZc=";
    };

    pyproject = true;
    build-system = with python.pkgs; [ setuptools ];

    propagatedBuildInputs = with python.pkgs; [
      protobuf
    ];

    doCheck = false;
    pythonImportsCheck = [ "discord_protos" ];

    meta = with lib; {
      description = "Discord protocol buffers for Python";
      homepage = "https://pypi.org/project/discord-protos/";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
    };
  };

  pythonEnv = python.withPackages (
    ps: with ps; [
      requests
      yarl
      aiohttp
      protobuf
      discordPySelf
      discordProtos
    ]
  );

in
pkgs.stdenv.mkDerivation rec {
  pname = "discord-relay";
  version = "unstable-2025-08-03";

  # Use local copy instead of Git
  #src = /home/chris/scripts/discord-relay;

  # Git source kept for reference:
  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/discord-relay.git";
    rev = "22c34795e71a9e38e3a1c5f88352e1df0801f267";
  };

  # Configuration overrides - edit these paths as needed
  workingDir = "~/.discord-relay";
  logsDir = "logs";
  attachmentCacheDir = "attachment_cache";

  nativeBuildInputs = [ pythonEnv ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/discord-relay

    # Copy the application files
    cp -r * $out/share/discord-relay/

    # Override config paths to use user's home directory
    substituteInPlace $out/share/discord-relay/config/config.py \
      --replace 'WORKING_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))' \
                'WORKING_DIR = os.path.expanduser("${workingDir}")' \
      --replace 'ATTACHMENT_CACHE_DIR = os.path.join(WORKING_DIR, "attachment_cache")' \
                'ATTACHMENT_CACHE_DIR = os.path.join(WORKING_DIR, "${attachmentCacheDir}")' \
      --replace 'LOG_DIR = os.path.join(WORKING_DIR, "logs")' \
                'LOG_DIR = os.path.join(WORKING_DIR, "${logsDir}")'

    # Create wrapper script that ensures directories exist
    cat > $out/bin/discord-relay << EOF
    #!${pkgs.bash}/bin/bash
    # Ensure config directories exist in user's home
    mkdir -p ${workingDir}/${logsDir}
    mkdir -p ${workingDir}/${attachmentCacheDir}
    cd $out/share/discord-relay
    exec ${pythonEnv}/bin/python main.py "\$@"
    EOF

    chmod +x $out/bin/discord-relay

    runHook postInstall
  '';

  meta = with lib; {
    description = "Discord Relay Bot";
    homepage = "https://github.com/h0lylag/discord-relay";
    platforms = platforms.linux;
  };
}
