{
  lib,
  pkgs,
}:

let
  pname = "eve-fundraiser";
  python = pkgs.python313;

  pythonEnv = python.withPackages (
    ps: with ps; [
      flask
      gunicorn
      python-dotenv
      requests
      sqlalchemy
    ]
  );

  testEnv = python.withPackages (
    ps: with ps; [
      flask
      pytest
      python-dotenv
      requests
      sqlalchemy
    ]
  );

  # Trust the forwarding headers from the loopback-only nginx proxy. In
  # particular, X-Forwarded-Prefix makes Flask generate URLs below
  # /titan-fund instead of at the root of gravemind.sh.
  wsgiModule = pkgs.writeText "eve-fundraiser-wsgi.py" ''
    from werkzeug.middleware.proxy_fix import ProxyFix

    from app import app


    app.wsgi_app = ProxyFix(
        app.wsgi_app,
        x_for=1,
        x_proto=1,
        x_host=1,
        x_prefix=1,
    )
  '';
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname;
  version = "unstable-2026-08-13";

  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/eve-fundraiser.git";
    rev = "e600b150f910a6d8ed893097e37bdd151dec32f2";
    allRefs = true;
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];
  nativeCheckInputs = [ testEnv ];

  postPatch = ''
    substituteInPlace fundraiser/routes.py \
      --replace-fail \
        'url_for("admin_login", next=request.path)' \
        'url_for("admin_login", next=request.script_root + request.path)' \
      --replace-fail \
        'return redirect(request.args.get("next") or url_for("admin_index"))' \
        'return redirect(url_for("admin_index"))'
  '';

  dontBuild = true;

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    ${testEnv}/bin/pytest -p no:cacheprovider

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/${pname}
    cp app.py $out/share/${pname}/
    cp -r fundraiser $out/share/${pname}/
    install -Dm644 ${wsgiModule} $out/share/${pname}/eve_fundraiser_wsgi.py

    makeWrapper ${pythonEnv}/bin/gunicorn $out/bin/${pname} \
      --add-flags "eve_fundraiser_wsgi:app" \
      --chdir "$out/share/${pname}" \
      --prefix PYTHONPATH : "$out/share/${pname}"

    makeWrapper ${pythonEnv}/bin/flask $out/bin/${pname}-sync \
      --add-flags "--app app sync-wallet" \
      --chdir "$out/share/${pname}" \
      --prefix PYTHONPATH : "$out/share/${pname}"

    runHook postInstall
  '';

  passthru = {
    inherit python pythonEnv;
  };

  meta = with lib; {
    description = "EVE Online titan fundraiser dashboard";
    homepage = "https://github.com/h0lylag/eve-fundraiser";
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
