{
  lib,
  pkgs,
}:

let
  pname = "prism-django";
  version = "unstable";

  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/prism-django.git";
    #ref = "main";
    rev = "ccaf1c5b608ea9cf94a50ee6dec08ae8ddf3fd4f"; # pin to specific commit for reproducibility
    # To get the latest commit hash: git ls-remote git@github.com:h0lylag/prism-django.git main
  };

  # Use Python 3.13 with Django 5.2
  python = pkgs.python313.override {
    packageOverrides = self: super: {
      django = super.django_5;

      # Override django-crispy-forms to use our Django 5 instead of its default
      django-crispy-forms = super.django-crispy-forms.override {
        django = self.django;
      };

      # crispy-bootstrap5 is not in nixpkgs, so we build it manually from PyPI
      crispy-bootstrap5 = self.buildPythonPackage rec {
        pname = "crispy-bootstrap5";
        version = "2025.6";
        format = "pyproject";

        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/97/30/36cc4144b6dff91bb54490a3b474897b7469bcda9517bf9f54681ea91011/crispy_bootstrap5-2025.6.tar.gz";
          sha256 = "sha256-8b3nysB0xlD8gvMXd9Skz9DfJRLGi8QSjyWcddParaQ=";
        };

        nativeBuildInputs = [
          super.setuptools
          super.wheel
        ];
        propagatedBuildInputs = [
          self.django
          self.django-crispy-forms
        ];

        # Skip tests to avoid test dependencies
        doCheck = false;

        meta = with lib; {
          description = "Bootstrap 5 template pack for django-crispy-forms";
          homepage = "https://github.com/django-crispy-forms/crispy-bootstrap5";
          license = licenses.mit;
        };
      };
    };
  };

  pythonEnv = python.withPackages (
    ps: with ps; [
      # Core Django
      django
      python-decouple

      # Database
      psycopg2
      dj-database-url

      # Forms & UI
      pillow
      django-crispy-forms
      crispy-bootstrap5

      # API
      djangorestframework

      requests

      # Redis support
      redis
      django-redis

      # Celery (background tasks)
      celery
      django-celery-results
      django-celery-beat

      # Production server
      gunicorn
    ]
  );
in
pkgs.stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    pythonEnv
    pkgs.makeWrapper
  ];

  # Don't strip Python bytecode
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Install the Django application
    mkdir -p $out/share/${pname}
    cp -r . $out/share/${pname}/

    # Remove .git directory if present (from fetchGit)
    rm -rf $out/share/${pname}/.git

    # Patch settings so STATIC_ROOT and MEDIA_ROOT respect environment overrides
    substituteInPlace $out/share/${pname}/prism/settings.py \
      --replace "STATIC_ROOT = BASE_DIR / 'staticfiles'" "STATIC_ROOT = Path(config('STATIC_ROOT', default=str(BASE_DIR / 'staticfiles')))" \
      --replace "MEDIA_ROOT = BASE_DIR / 'media'" "MEDIA_ROOT = Path(config('MEDIA_ROOT', default=str(BASE_DIR / 'media')))"

    # Create bin directory for wrapper scripts
    mkdir -p $out/bin

    # Django management command wrapper
    makeWrapper ${pythonEnv}/bin/python $out/bin/prism-manage \
      --add-flags "$out/share/${pname}/manage.py" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    # Gunicorn production server wrapper
    makeWrapper ${pythonEnv}/bin/gunicorn $out/bin/prism-gunicorn \
      --add-flags "prism.wsgi:application" \
      --add-flags "--config" \
      --add-flags "$out/share/${pname}/gunicorn.conf.py" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]} \
      --prefix PYTHONPATH : "$out/share/${pname}"

    # Django runserver wrapper (development only)
    makeWrapper ${pythonEnv}/bin/python $out/bin/prism-runserver \
      --add-flags "$out/share/${pname}/manage.py" \
      --add-flags "runserver" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    # Static file collection wrapper (for use in systemd preStart)
    makeWrapper ${pythonEnv}/bin/python $out/bin/prism-collectstatic \
      --add-flags "$out/share/${pname}/manage.py" \
      --add-flags "collectstatic" \
      --add-flags "--noinput" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    # Migration wrapper (for use in systemd preStart)
    makeWrapper ${pythonEnv}/bin/python $out/bin/prism-migrate \
      --add-flags "$out/share/${pname}/manage.py" \
      --add-flags "migrate" \
      --add-flags "--noinput" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    # Celery worker wrapper
    makeWrapper ${pythonEnv}/bin/celery $out/bin/prism-celery-worker \
      --add-flags "-A" \
      --add-flags "prism" \
      --add-flags "worker" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]} \
      --prefix PYTHONPATH : "$out/share/${pname}"

    # Celery beat (scheduler) wrapper
    makeWrapper ${pythonEnv}/bin/celery $out/bin/prism-celery-beat \
      --add-flags "-A" \
      --add-flags "prism" \
      --add-flags "beat" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]} \
      --prefix PYTHONPATH : "$out/share/${pname}"

    runHook postInstall
  '';

  # Runtime dependencies that need to be available
  propagatedBuildInputs = [ pythonEnv ];

  passthru = {
    inherit python pythonEnv;

    # Expose the application root for NixOS module
    appRoot = "${placeholder "out"}/share/${pname}";

    # Provide test command
    tests = {
      basic-import = pkgs.runCommand "prism-django-test" { } ''
        ${pythonEnv}/bin/python -c "import django; print(django.VERSION)" > $out
      '';
    };
  };

  meta = with lib; {
    description = "PRISM";
    longDescription = ''
      Prism is a Django-based data aggregation backend.
    '';
    homepage = "https://github.com/h0lylag/prism-django";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "prism-gunicorn";
    maintainers = [ ];
  };
}
