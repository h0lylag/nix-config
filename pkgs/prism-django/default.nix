{
  lib,
  pkgs,
}:

let
  pname = "prism-django";
  version = "unstable";

  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/prism-django.git";
    ref = "main";
    # rev = "abc123..."; # Uncomment and pin to specific commit for reproducibility
    # To get the latest commit hash: git ls-remote git@github.com:h0lylag/prism-django.git main
  };

  # Use Python 3.13 with Django 5.2 instead of 4.2
  # This packageOverrides ensures all Django ecosystem packages use Django 5.2
  python = pkgs.python313.override {
    packageOverrides = self: super: {
      django = super.django_5_2;
    };
  };

  pythonEnv = python.withPackages (
    ps: with ps; [
      django
      python-decouple
      pillow
      django-crispy-forms
      crispy-bootstrap5
      psycopg2
      dj-database-url
      djangorestframework
    ]
  );
in
pkgs.stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    pythonEnv
    pkgs.makeWrapper
  ];

  installPhase = ''
        runHook preInstall

        # Install the Django app
        mkdir -p $out/share/${pname}
        cp -r . $out/share/${pname}/

        # Create wrapper scripts
        mkdir -p $out/bin

        # Django management command wrapper
        cat > $out/bin/prism-manage <<'EOF'
    #!/usr/bin/env bash
    SCRIPT_DIR="$(dirname "$0")/../share/${pname}"
    cd "$SCRIPT_DIR"
    exec ${pythonEnv}/bin/python manage.py "$@"
    EOF
        chmod +x $out/bin/prism-manage

        # Django runserver wrapper
        cat > $out/bin/prism-runserver <<'EOF'
    #!/usr/bin/env bash
    SCRIPT_DIR="$(dirname "$0")/../share/${pname}"
    cd "$SCRIPT_DIR"
    exec ${pythonEnv}/bin/python manage.py runserver "$@"
    EOF
        chmod +x $out/bin/prism-runserver

        runHook postInstall
  '';

  meta = with lib; {
    description = "PRISM Django application";
    homepage = "https://github.com/h0lylag/prism-django";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "prism-manage";
  };
}
