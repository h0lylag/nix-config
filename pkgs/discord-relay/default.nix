{
  lib,
  pkgs,
  python312,
}:

let
  python = python312;

  # Custom discord.py-self package for Python 3.12 compatibility
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

    meta = with lib; {
      description = "A Python wrapper for the Discord user API";
      homepage = "https://github.com/dolfies/discord.py-self";
      license = licenses.mit;
    };
  };

  # Discord protocol buffers dependency
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

  # Python environment with all dependencies
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

  # Source configuration - switch between local and remote as needed
  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/discord-relay.git";
    rev = "facc962c1b6b62667d8de410967e044e9a6b18ba";
  };
  # Local development source (uncomment to use):
  # src = /home/chris/scripts/discord-relay;

  # Directory variables for easy configuration
  # ALL MUST BE ABSOLUTE PATHS
  configDir = "/home/discord-relay";
  workingDir = "/home/discord-relay";
  attachmentCacheDir = "/home/discord-relay/attachment_cache";
  logsDir = "/home/discord-relay/logs";

  nativeBuildInputs = [ pythonEnv ];

  installPhase = ''
        runHook preInstall

        # Install application files
        mkdir -p $out/bin $out/share/discord-relay
        cp -r * $out/share/discord-relay/

        # Patch config.py to use system directories instead of local paths
        substituteInPlace $out/share/discord-relay/config/config.py \
          --replace 'CONFIG_DIR = os.path.dirname(__file__)' \
                    'CONFIG_DIR = "${configDir}"' \
          --replace 'WORKING_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))' \
                    'WORKING_DIR = "${workingDir}"' \
          --replace 'ATTACHMENT_CACHE_DIR = os.path.join(WORKING_DIR, "attachment_cache")' \
                    'ATTACHMENT_CACHE_DIR = "${attachmentCacheDir}"' \
          --replace 'LOG_DIR = os.path.join(WORKING_DIR, "logs")' \
                    'LOG_DIR = "${logsDir}"'

        # Create launcher script with directory setup
        cat > $out/bin/discord-relay << EOF
    #!/usr/bin/env bash
    # Ensure user directories exist
    mkdir -p ${attachmentCacheDir}
    mkdir -p ${logsDir}
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
    mainProgram = "discord-relay";
  };
}
