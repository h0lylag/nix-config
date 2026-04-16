{
  lib,
  pkgs,
  python313,
  stateDir ? "/var/lib/discord-relay",
}:

let
  python = python313;

  # Discord protocol buffers dependency (required by discordPySelf)
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

  discordPySelf = python.pkgs.buildPythonPackage rec {
    pname = "discord.py-self";
    version = "2.1.0";

    src = pkgs.fetchPypi {
      pname = "discord_py_self";
      inherit version;
      sha256 = "sha256-m8bYdxHpNFeE8u0jyrvmPrqWcwCOW0YKol41RlcLzQc=";
    };

    pyproject = true;
    build-system = with python.pkgs; [ setuptools ];
    propagatedBuildInputs = with python.pkgs; [
      aiohttp
      yarl
      curl-cffi
      tzlocal
      audioop-lts # removed from stdlib in Python 3.13
      # speed extras
      orjson
      aiodns
      brotli
      zstandard
    ] ++ [ discordProtos ];

    doCheck = false;

    meta = with lib; {
      description = "A Python wrapper for the Discord user API";
      homepage = "https://github.com/dolfies/discord.py-self";
      license = licenses.mit;
    };
  };

  # python.withPackages resolves all propagatedBuildInputs transitively,
  # so only discordPySelf (and requests, which the app uses directly) are needed here.
  pythonEnv = python.withPackages (ps: [
    discordPySelf
    ps.requests
  ]);

in
pkgs.stdenv.mkDerivation {
  pname = "discord-relay";
  version = "unstable-2025-08-03";

  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/discord-relay.git";
    rev = "65a63e02265add7ba0ba4813a39c3252cb28b494";
    allRefs = true;
  };
  # Local development source (uncomment to use):
  # src = /home/chris/scripts/discord-relay;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/discord-relay
    cp -r * $out/share/discord-relay/

    # Patch config.py to use state directory paths instead of local paths
    substituteInPlace $out/share/discord-relay/config/config.py \
      --replace 'CONFIG_DIR = os.path.dirname(__file__)' \
                'CONFIG_DIR = "${stateDir}/config"' \
      --replace 'WORKING_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))' \
                'WORKING_DIR = "${stateDir}"' \
      --replace 'ATTACHMENT_CACHE_DIR = os.path.join(WORKING_DIR, "attachment_cache")' \
                'ATTACHMENT_CACHE_DIR = "${stateDir}/attachment_cache"' \
      --replace 'LOG_DIR = os.path.join(WORKING_DIR, "logs")' \
                'LOG_DIR = "${stateDir}/logs"'

    cat > $out/bin/discord-relay << EOF
#!/usr/bin/env bash
cd $out/share/discord-relay
exec ${pythonEnv}/bin/python main.py "\$@"
EOF
    chmod +x $out/bin/discord-relay

    wrapProgram $out/bin/discord-relay \
      --set LD_LIBRARY_PATH "${pkgs.stdenv.cc.cc.lib}/lib"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Discord Relay Bot";
    homepage = "https://github.com/h0lylag/discord-relay";
    platforms = platforms.linux;
    mainProgram = "discord-relay";
  };
}
