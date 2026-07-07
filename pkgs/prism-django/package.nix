{
  lib,
  pkgs,
}:

let
  pname = "prism-django";
  version = "unstable";

  src = builtins.fetchGit {
    url = "git@github.com:Outback-Steakhouse-Of-Pancakes/prism-django.git";
    #ref = "main";
    rev = "3a5eab6e996dd6a0291e73ac00499254f2bdc8ad"; # pin to specific commit for reproducibility
    # To get the latest commit hash: git ls-remote git@github.com:Outback-Steakhouse-Of-Pancakes/prism-django.git main
  };

  # Use Python 3.13 with Django 5.2
  python = pkgs.python313.override {
    packageOverrides = self: super: {
      django = super.django_5;

      # Override django-crispy-forms to use our Django 5 instead of its default
      django-crispy-forms = super.django-crispy-forms.override {
        django = self.django;
      };

      # django-esi 9.6 requires a newer Pydantic stack than the pinned nixpkgs
      # revision. Use the matching CPython 3.13 wheels to keep this dependency
      # pair reproducible without relaxing upstream version constraints.
      pydantic-core = self.buildPythonPackage rec {
        pname = "pydantic-core";
        version = "2.47.0";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/cp313/p/pydantic-core/pydantic_core-${version}-cp313-cp313-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
          hash = "sha256-RzuaKyofDdVcuzLSuQL5O6vn8UGgu0j7TT1NKz6T6aA=";
        };
        propagatedBuildInputs = [ self.typing-extensions ];
        doCheck = false;
      };

      pydantic = self.buildPythonPackage rec {
        pname = "pydantic";
        version = "2.14.0a1";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/py3/p/pydantic/pydantic-${version}-py3-none-any.whl";
          hash = "sha256-YaHqjWXflbaBwfq5zX0BskcoN/eY31PcbQ9B8MIXsGE=";
        };
        propagatedBuildInputs = [
          self.annotated-types
          self.pydantic-core
          self.typing-extensions
          self.typing-inspection
        ];
        doCheck = false;
      };

      jsonseq = self.buildPythonPackage rec {
        pname = "jsonseq";
        version = "1.0.0";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/py3/j/jsonseq/jsonseq-${version}-py3-none-any.whl";
          hash = "sha256-1K3ZFkIPwCeWpQPlnOTYAIFSgw/RYlzHBpKx+YCjIjE=";
        };
        doCheck = false;
      };

      aiopenapi3 = self.buildPythonPackage rec {
        pname = "aiopenapi3";
        version = "0.10.0";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/py3/a/aiopenapi3/aiopenapi3-${version}-py3-none-any.whl";
          hash = "sha256-s6Pw5POUIe3cdyG4RAQ3ms9WrPZRRYp6w65o2ZNJUe8=";
        };
        propagatedBuildInputs = [
          self.email-validator
          self.httpx
          self.ijson
          self.jmespath
          self.jsonseq
          self.more-itertools
          self.pydantic
          self.pyyaml
          self.typing-extensions
          self.yarl
        ];
        doCheck = false;
      };

      celery-once = self.buildPythonPackage rec {
        pname = "celery-once";
        version = "3.0.1";
        format = "pyproject";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/source/c/celery-once/celery_once-${version}.tar.gz";
          hash = "sha256-kJhzDWqEqRzNhIaMRzCoFIf9D/tyIMsYNtK5KFQhWdA=";
        };
        nativeBuildInputs = [
          self.setuptools
          self.wheel
        ];
        propagatedBuildInputs = [
          self.celery
          self.redis
        ];
        doCheck = false;
      };

      django-bitfield = self.buildPythonPackage rec {
        pname = "django-bitfield";
        version = "2.2.0";
        format = "pyproject";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/1a/fc/872e9c94107a7ed3b9534c76be29cdc6697cc27332075fccc384e8c30b93/django-bitfield-${version}.tar.gz";
          hash = "sha256-GyEmKsxOwK8/gu0ESYoFbNnVRSUyrAJ3HgBINaNOCxs=";
        };
        nativeBuildInputs = [
          self.setuptools
          self.wheel
        ];
        propagatedBuildInputs = [
          self.django
          self.six
        ];
        doCheck = false;
      };

      django-esi = self.buildPythonPackage rec {
        pname = "django-esi";
        version = "9.6.0";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/py3/d/django-esi/django_esi-${version}-py3-none-any.whl";
          hash = "sha256-LYwIWmG707Hi0iUpdLFCIS/4TXNSwG0qPJu1WMTD0x4=";
        };
        propagatedBuildInputs = [
          self.aiopenapi3
          self.brotli
          self.celery
          self.django
          self.django-redis
          self.h2
          self.httpx
          self.python-jose
          self.requests
          self.requests-oauthlib
          self.tenacity
          self.zstandard
        ];
        doCheck = false;
      };

      django-eveuniverse = self.buildPythonPackage rec {
        pname = "django-eveuniverse";
        version = "2.0.0";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/py3/d/django-eveuniverse/django_eveuniverse-${version}-py3-none-any.whl";
          hash = "sha256-Ib1PTJtIZIDzMlbeYU29M0mKSMjoevUxRTrj75mZOmA=";
        };
        propagatedBuildInputs = [
          self.celery
          self.celery-once
          self.django
          self.django-bitfield
          self.django-esi
          self.requests
          self.typing-extensions
        ];
        doCheck = false;
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

      # EVE Online universe data and ESI client
      django-eveuniverse

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

    # Fail the package build early if the EVE dependency stack is incomplete.
    ${pythonEnv}/bin/python -c "import aiopenapi3, esi, eveuniverse, pydantic"

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
    homepage = "https://github.com/Outback-Steakhouse-Of-Pancakes/prism-django";
    license = licenses.mit;
    # pydantic-core is pinned to its CPython 3.13 x86_64 wheel above.
    platforms = [ "x86_64-linux" ];
    mainProgram = "prism-gunicorn";
    maintainers = [ ];
  };
}
