{
  lib,
  pkgs,
}:

let
  pname = "imgcat-django";
  version = "unstable";

  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/imgcat-django.git";
    ref = "main";
    rev = "e5386587d5150a6c5dfa96d05b0c4adc934c2387";
  };

  # django_6 is only in unstable nixpkgs; call this via pkgs.unstable.callPackage
  python = pkgs.python313.override {
    packageOverrides = self: super: {
      # django_6 should be available in nixpkgs by the time this is used.
      # If not available, replace with a fetchPypi buildPythonPackage for Django==6.0.x
      django = super.django_6;

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

      # python-magic requires the system libmagic library
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
      sqlparse

      # Database
      psycopg2 # PostgreSQL (SQLite is built-in)

      # Image processing
      pillow

      # Rate limiting
      django-ratelimit

      # File type detection
      python-magic

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

    # Migration wrapper (for use in systemd preStart)
    makeWrapper ${pythonEnv}/bin/python $out/bin/imgcat-migrate \
      --add-flags "$out/share/${pname}/manage.py" \
      --add-flags "migrate" \
      --add-flags "--noinput" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    # Static file collection wrapper (for use in systemd preStart)
    makeWrapper ${pythonEnv}/bin/python $out/bin/imgcat-collectstatic \
      --add-flags "$out/share/${pname}/manage.py" \
      --add-flags "collectstatic" \
      --add-flags "--noinput" \
      --chdir "$out/share/${pname}" \
      --prefix PATH : ${lib.makeBinPath [ pythonEnv ]}

    runHook postInstall
  '';

  propagatedBuildInputs = [
    pythonEnv
    pkgs.file
  ];

  passthru = {
    inherit python pythonEnv;
    appRoot = "${placeholder "out"}/share/${pname}";

    tests = {
      basic-import = pkgs.runCommand "imgcat-django-test" { } ''
        ${pythonEnv}/bin/python -c "import django; print(django.VERSION)" > $out
      '';
    };
  };

  meta = with lib; {
    description = "img.cat - Django-based image hosting and gallery platform";
    homepage = "https://github.com/h0lylag/imgcat-django";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "imgcat-gunicorn";
    maintainers = [ ];
  };
}
