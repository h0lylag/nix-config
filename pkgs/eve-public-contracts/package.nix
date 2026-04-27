{
  lib,
  pkgs,
}:

let
  python = pkgs.python313;

  pythonEnv = python.withPackages (
    ps: with ps; [
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
  version = "unstable-2026-04-27";

  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/eve-public-contracts.git";
    rev = "76791ab71edd618dd2ce5ce9dc92299cfa4242fa";
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
