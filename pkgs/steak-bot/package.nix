{
  lib,
  pkgs,
  python313,
  stateDir ? "/var/lib/discord-relay",
}:

let
  python = python313;

  pythonEnv = python.withPackages (ps: [
    ps.discordpy
    ps.aiohttp
    ps.psycopg
  ]);

in
pkgs.stdenv.mkDerivation {
  pname = "steak-bot";
  version = "unstable-2026-06-22";

  # Keep this pin in step with pkgs/discord-relay/package.nix until the source
  # repo is split.
  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/discord-relay.git";
    rev = "ebb60fab4ae85ae739d4e7b547cf5bdb314ea322";
    allRefs = true;
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/steak-bot
    cp -r * $out/share/steak-bot/

    # Reuse the relay config/state layout. The config module is shared with the
    # self-client package, so rewrite its runtime paths the same way.
    substituteInPlace $out/share/steak-bot/config/config.py \
      --replace 'CONFIG_DIR = os.path.dirname(__file__)' \
                'CONFIG_DIR = "${stateDir}/config"' \
      --replace 'WORKING_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))' \
                'WORKING_DIR = "${stateDir}"' \
      --replace 'ATTACHMENT_CACHE_DIR = os.path.join(WORKING_DIR, "attachment_cache")' \
                'ATTACHMENT_CACHE_DIR = "${stateDir}/attachment_cache"' \
      --replace 'LOG_DIR = os.path.join(WORKING_DIR, "logs")' \
                'LOG_DIR = "${stateDir}/logs"'

    cat > $out/bin/steak-bot << EOF
    #!/usr/bin/env bash
    cd $out/share/steak-bot
    exec ${pythonEnv}/bin/python -m steak_bot.main "\$@"
    EOF
    chmod +x $out/bin/steak-bot

    runHook postInstall
  '';

  meta = with lib; {
    description = "Steak-Bot relay server operator";
    homepage = "https://github.com/h0lylag/discord-relay";
    platforms = platforms.linux;
    mainProgram = "steak-bot";
  };
}
