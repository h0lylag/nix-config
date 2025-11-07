{
  lib,
  pkgs,
}:

let
  pname = "imgcat-django";
  version = "unstable";

  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/imgcat-django.git";
    #ref = "main";
    rev = "HEAD"; # Update with: git ls-remote git@github.com:h0lylag/imgcat-django.git main
    allRefs = true;
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
        version = "2024.10";
        format = "pyproject";

        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/3a/28/6257434e1f5cca2c7a05ac06a491f2fdc1881e103efabfbd0ec8b4d57e46/crispy_bootstrap5-2024.10.tar.gz";
          sha256 = "sha256-fRlhJYSzz6pHppSMr5SYNvJD9KcVkfLO6dqLjJIm/Ik=";
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

      # django-ratelimit is not in nixpkgs
      django-ratelimit = self.buildPythonPackage rec {
        pname = "django-ratelimit";
        version = "4.1.0";
        format = "setuptools";

        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/6f/8f/94038fe739b095aca3e4708ecc8a4e77f1fcfd87bed5d6baff43d4c80bc4/django-ratelimit-4.1.0.tar.gz";
          sha256 = "sha256-qsuohz5JNFjn6qHxnPJcdGQzW1VJxJVJTvvVyKxJmcY=";
        };

        propagatedBuildInputs = [
          self.django
        ];

        doCheck = false;

        meta = with lib; {
          description = "Cache-based rate-limiting for Django";
          homepage = "https://github.com/jsocol/django-ratelimit";
          license = licenses.asl20;
        };
      };

      # python-magic might need system libmagic
      python-magic = super.python-magic.overrideAttrs (old: {
        propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pkgs.file ];
      });
    };
  };

  pythonEnv = python.withPackages (
    ps: with ps; [
      # Core Django
      django
      python-decouple

      # Database (SQLite is built-in)
      # Add psycopg2 if switching to PostgreSQL

      # Forms & UI
      pillow
      django-crispy-forms
      crispy-bootstrap5

      # Rate limiting
      django-ratelimit

      # File type detection
      python-magic

      # Production server
      gunicorn
      whitenoise
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
    substituteInPlace $out/share/${pname}/imgcat/settings.py \
      --replace "STATIC_ROOT = BASE_DIR / 'staticfiles'" "STATIC_ROOT = Path(config('STATIC_ROOT', default=str(BASE_DIR / 'staticfiles')))" \
      --replace "MEDIA_ROOT = os.path.join(BASE_DIR, 'media')" "MEDIA_ROOT = config('MEDIA_ROOT', default=os.path.join(BASE_DIR, 'media'))"

    # Create bin directory for wrapper scripts
    mkdir -p $out/bin

    # Django management command wrapper
    makeWrapper ${pythonEnv}/bin/python $out/bin/imgcat-manage \
      --add-flags "$out/share/${pname}/manage.py" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    # Gunicorn production server wrapper
    makeWrapper ${pythonEnv}/bin/gunicorn $out/bin/imgcat-gunicorn \
      --add-flags "imgcat.wsgi:application" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]} \
      --prefix PYTHONPATH : "$out/share/${pname}"

    # Django runserver wrapper (development only)
    makeWrapper ${pythonEnv}/bin/python $out/bin/imgcat-runserver \
      --add-flags "$out/share/${pname}/manage.py" \
      --add-flags "runserver" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    # Static file collection wrapper (for use in systemd preStart)
    makeWrapper ${pythonEnv}/bin/python $out/bin/imgcat-collectstatic \
      --add-flags "$out/share/${pname}/manage.py" \
      --add-flags "collectstatic" \
      --add-flags "--noinput" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    # Migration wrapper (for use in systemd preStart)
    makeWrapper ${pythonEnv}/bin/python $out/bin/imgcat-migrate \
      --add-flags "$out/share/${pname}/manage.py" \
      --add-flags "migrate" \
      --add-flags "--noinput" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    runHook postInstall
  '';

  # Runtime dependencies that need to be available
  propagatedBuildInputs = [
    pythonEnv
    pkgs.file
  ];

  passthru = {
    inherit python pythonEnv;

    # Expose the application root for NixOS module
    appRoot = "${placeholder "out"}/share/${pname}";

    # Provide test command
    tests = {
      basic-import = pkgs.runCommand "imgcat-django-test" { } ''
        ${pythonEnv}/bin/python -c "import django; print(django.VERSION)" > $out
      '';
    };
  };

  meta = with lib; {
    description = "img.cat - Django-based image hosting and gallery platform";
    longDescription = ''
      img.cat is a Django-based image hosting and gallery platform with
      user authentication, album management, and image processing features.
    '';
    homepage = "https://github.com/h0lylag/imgcat-django";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "imgcat-gunicorn";
    maintainers = [ ];
  };
}
