{
  lib,
  pkgs,
  python313,
  stateDir ? "/var/lib/discord-relay",
}:

let
  python = python313;

  # nixpkgs 25.11 ships curl-cffi 0.14.0b2 (pre-release); discord.py-self 2.1.0 requires >=0.14.0
  # stable (PEP 440: pre-releases don't satisfy a plain >=X.Y.Z constraint). Override with the
  # stable tarball. Remove this block once nixpkgs 25.11 promotes curl-cffi to 0.14.0 stable.
  curlCffi = python.pkgs.curl-cffi.overridePythonAttrs (_: {
    version = "0.14.0";
    src = pkgs.fetchPypi {
      pname = "curl_cffi";
      version = "0.14.0";
      sha256 = "sha256-X/vILlnwUAjsCOpDLw5TVBiCPNpEF47lGJBqVPJ6Xw8=";
    };
    doCheck = false; # test fixtures (assets/scrapfly.png) are not included in the PyPI sdist
  });

  # Not in nixpkgs; required by discord.py-self for its protobuf-based gateway encoding
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

  # Not in nixpkgs; fork of discord.py
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
    propagatedBuildInputs =
      with python.pkgs;
      [
        aiohttp
        yarl
        tzlocal
        audioop-lts # removed from Python 3.13 stdlib
        orjson
        aiodns
        brotli
        zstandard
      ]
      ++ [
        curlCffi
        discordProtos
      ];

    doCheck = false;
    pythonImportsCheck = [ "discord" ];

    meta = with lib; {
      description = "A Python wrapper for the Discord user API";
      homepage = "https://github.com/dolfies/discord.py-self";
      license = licenses.mit;
    };
  };

  # python.withPackages resolves propagatedBuildInputs transitively, so listing discordPySelf
  # here is sufficient — curlCffi and discordProtos are pulled in automatically.
  pythonEnv = python.withPackages (ps: [
    discordPySelf
    ps.requests
    ps.psycopg
  ]);

in
pkgs.stdenv.mkDerivation {
  pname = "discord-relay";
  version = "unstable-2026-05-02";

  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/discord-relay.git";
    rev = "3316b3fdb4fe3632365e96c8c13554cf4fea2abc";
    allRefs = true;
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/discord-relay
    cp -r * $out/share/discord-relay/

    # Rewrite the hardcoded relative paths in config.py to the runtime state directory.
    # The state directory itself is created at activation time by systemd.tmpfiles.rules.
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

    cat > $out/bin/discord-relay-backfill << EOF
    #!/usr/bin/env bash
    cd $out/share/discord-relay
    exec ${pythonEnv}/bin/python main.py --backfill "\$@"
    EOF
    chmod +x $out/bin/discord-relay-backfill

    # curl-cffi links against libcurl-impersonate, a non-standard shared lib that won't be
    # on the default LD path. Bake it in via wrapProgram rather than leaking it into the service.
    wrapProgram $out/bin/discord-relay \
      --set LD_LIBRARY_PATH "${pkgs.stdenv.cc.cc.lib}/lib"
    wrapProgram $out/bin/discord-relay-backfill \
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
