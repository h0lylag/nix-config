{
  lib,
  python3Packages,
  nix-update-script,
}:

python3Packages.buildPythonApplication rec {
  pname = "harbor";
  version = "0.25.0";
  pyproject = true;

  src = python3Packages.fetchPypi {
    inherit pname version;
    hash = "sha256-pmVDoiNTnNhTiJ7g7qd9FaPlIiljQYqHwPB5tj2ttLI=";
  };

  # Upstream builds with the uv build backend; nixpkgs carries an older
  # uv-build than the sdist pins. Relax the build-system pin (pip enforces
  # it even with --no-isolation); the packaged backend handles this
  # package's simple src-layout configuration.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"uv_build>=0.13.5,<0.14"' '"uv_build"'
  '';

  build-system = with python3Packages; [
    uv-build
  ];

  dependencies = with python3Packages; [
    certifi
    fastapi
    filelock
    httpx
    jinja2
    jsonschema
    litellm
    dirhash
    packaging
    pathspec
    platformdirs
    pydantic
    pyjwt
    python-dotenv
    pyyaml
    requests
    semver
    shortuuid
    supabase
    tenacity
    toml
    typer
    uvicorn
  ];

  # Upstream tests drive real container runtimes and paid LLM APIs.
  doCheck = false;

  # harbor pins certifi>=2026.10.19; no locked input carries it yet and the
  # newer releases only refresh the CA bundle.
  dontCheckRuntimeDeps = 1;

  pythonImportsCheck = [ "harbor" ];

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Framework for evaluating and optimizing agents in sandboxed environments";
    homepage = "https://github.com/harbor-framework/harbor";
    changelog = "https://github.com/harbor-framework/harbor/blob/main/CHANGELOG.md";
    license = licenses.asl20;
    mainProgram = "harbor";
    # The local `docker` and `podman` environment backends shell out to the
    # container CLI; provide docker or enable virtualisation.podman on hosts
    # that run benchmarks.
    platforms = platforms.linux;
  };
}
