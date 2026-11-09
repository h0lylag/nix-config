{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  git,
  makeWrapper,
  python3,
  rocmPackages,
  # Architectures the engine's GPU code is compiled for. Strata validates
  # gfx1100 (RX 7900 XT/XTX) and gfx1201 (RX 9070 series); other wave32
  # targets build with a warning.
  gpuTargets ? [ "gfx1100" ],
}:
let
  pythonEnv = python3.withPackages (
    ps: with ps; [
      numpy
      jinja2
      regex
      pyyaml
      tqdm
      requests
      pillow
      psutil
    ]
  );

  # ggml is built from this exact llama.cpp commit, pinned by
  # third_party/ggml/VERSION.txt and CMakeLists.txt. Strata would otherwise
  # fetch it at configure time, which the sandbox forbids.
  llamaCpp = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "3cf03257f219afbe7334045ff7c6a06ac68c627d";
    hash = "sha256-SRGoXa+4ACBCB3eaG9XFYhMN1i0FyPEy9Rrer+dFGYI=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "strata";
  version = "0.2.12";

  src = fetchFromGitHub {
    owner = "Niko1221";
    repo = "Strata";
    tag = "v${finalAttrs.version}";
    hash = "sha256-iMjGRmrr2luO7O0x5QF4iIWpOVRQp1mlSeTWFDGZEVo=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    git
    makeWrapper
    rocmPackages.clr
  ];

  buildInputs = with rocmPackages; [
    clr
    hipblas
    hipblaslt
    rocblas
  ];

  cmakeBuildType = "Release";

  cmakeFlags = [
    (lib.cmakeBool "STRATA_ENABLE_HIP" true)
    (lib.cmakeBool "STRATA_ENABLE_CUDA" false)
    (lib.cmakeBool "STRATA_BUILD_TESTS" false)
    (lib.cmakeBool "STRATA_PREFILL_MMQ" true)
    (lib.cmakeBool "STRATA_Q6K_EXPERTS" true)
    (lib.cmakeBool "STRATA_MMQ_KQUANTS" true)
    (lib.cmakeFeature "CMAKE_HIP_ARCHITECTURES" (lib.concatStringsSep ";" gpuTargets))
    (lib.cmakeFeature "CMAKE_HIP_COMPILER" "${rocmPackages.clr.hipClangPath}/clang++")
    (lib.cmakeFeature "STRATA_GGML_DIR" "${llamaCpp}")
  ];

  # Only the GPU-facing executables are needed; the rest are tools and tests.
  ninjaFlags = [
    "strata"
    "strata-device"
  ];

  installPhase = ''
    runHook preInstall

    share=$out/share/strata
    mkdir -p $share
    cp -r ../strata.py ../setup.py ../strata_cli ../strata_control ../serve ../bin ../data ../tools ../ref ../packaging ../integrations $share/
    chmod -R u+w $share
    rm -f $share/bin/strata.cmd $share/bin/strata.ps1
    echo ${finalAttrs.version} > $share/VERSION

    engineVersion=$(sed -n 's/^project(strata VERSION \([0-9.]*\).*/\1/p' ../CMakeLists.txt)
    install -Dm755 strata strata-device -t $share/components/engine/$engineVersion-linux-x86_64-hip

    # strata_cli and the server are Python; the engine finds its GPU
    # libraries through its RPATH.
    mkdir -p $out/bin
    makeWrapper $share/bin/strata $out/bin/strata \
      --set STRATA_PYTHON ${pythonEnv}/bin/python3 \
      --set-default STRATA_COMPONENTS_DIR $share/components

    runHook postInstall
  '';

  # Control checks the engine as a component package whose manifest lists each
  # file's hash. Write it after fixup, which rewrites the binaries' RPATHs.
  postFixup = ''
    component=$(echo $out/share/strata/components/engine/*)
    engineVersion=$(basename $component)
    engineVersion=''${engineVersion%%-*}
    ${lib.getExe python3} - "$component" "$engineVersion" ${lib.escapeShellArg (lib.concatStringsSep "," gpuTargets)} <<'PY'
    import hashlib, json, pathlib, sys
    root, version, archs = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3].split(",")
    files = [
        {"path": f.name, "sha256": hashlib.sha256(f.read_bytes()).hexdigest(), "bytes": f.stat().st_size}
        for f in sorted(root.iterdir())
    ]
    (root / "engine-component.json").write_text(json.dumps({
        "schema_version": 2, "id": "strata-engine", "name": "strata-engine",
        "version": version, "platform": "linux-x86_64", "backend": "hip",
        "archs": archs, "min_driver": {}, "build_id": "nixpkgs",
        "entrypoint": "strata", "files": files, "signature": None,
    }, indent=1))
    PY
  '';

  # Strata's model preparation reads GGUF files with this checkout's gguf-py.
  passthru = { inherit llamaCpp; };

  meta = {
    description = "Local inference engine and OpenAI/Anthropic-compatible server for Qwen3.8-Flash-Next and other MoE models";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "strata";
  };
})
