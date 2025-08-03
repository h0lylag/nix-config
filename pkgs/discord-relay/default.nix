{
  lib,
  pkgs,
  python3,
}:

let
  python = python3;

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

  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/discord-relay.git";
    rev = "d59277c4fa63c5252828e6a15940d960ae8b401b";
  };

  nativeBuildInputs = [ pythonEnv ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/discord-relay

    # Copy the application files
    cp -r * $out/share/discord-relay/

    # Create wrapper script
    cat > $out/bin/discord-relay << EOF
    #!${pkgs.bash}/bin/bash
    exec ${pythonEnv}/bin/python $out/share/discord-relay/main.py "\$@"
    EOF

    chmod +x $out/bin/discord-relay

    runHook postInstall
  '';

  meta = with lib; {
    description = "Discord Relay Bot";
    homepage = "https://github.com/h0lylag/discord-relay";
    license = licenses.mit; # Adjust based on your actual license
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
