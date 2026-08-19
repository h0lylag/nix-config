{
  lib,
  pkgs,
}:

let
  python = pkgs.python313;

  pythonEnv = python.withPackages (
    ps: with ps; [
      discordpy
      psycopg2
      python-dotenv
      requests
      sqlalchemy
      sqlalchemy-utils
    ]
  );

  pname = "eve-public-contracts";

in
pkgs.stdenv.mkDerivation {
  inherit pname;
  version = "unstable-2026-08-18";

  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/eve-public-contracts.git";
    rev = "7f9b6f8d5d888dbe95eae3b6d7146a8c06425fe2";
    allRefs = true;
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/${pname}
    cp -r . $out/share/${pname}/
    rm -rf $out/share/${pname}/.git

    makeWrapper ${pythonEnv}/bin/python $out/bin/${pname} \
      --add-flags "$out/share/${pname}/main.py" \
      --chdir "$out/share/${pname}" \
      --prefix PYTHONPATH : "$out/share/${pname}"

    makeWrapper ${pythonEnv}/bin/python $out/bin/${pname}-bot \
      --add-flags "-m discord_bot" \
      --chdir "$out/share/${pname}" \
      --prefix PYTHONPATH : "$out/share/${pname}"

    runHook postInstall
  '';

  passthru = {
    inherit python pythonEnv;
  };

  meta = with lib; {
    description = "EVE Online public contracts fetcher and Discord notifier";
    homepage = "https://github.com/h0lylag/eve-public-contracts";
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
