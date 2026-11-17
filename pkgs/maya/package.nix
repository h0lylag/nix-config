{
  lib,
  stdenv,
  stdenvNoCC,
  callPackage,
  fetchFromGitHub,
  replaceVars,
  runtimeShell,
  symlinkJoin,
  python3,
  rocmPackages,
  # Architectures the GPU code is compiled for. Maya validates gfx1100
  # (RX 7900 XT/XTX), gfx1201 (RX 9070 series, R9700) and gfx1151 (Strix Halo).
  gpuTargets ? [ "gfx1100" ],
}:
let
  version = "1.1.65";

  src = fetchFromGitHub {
    owner = "mw00";
    repo = "project-maya";
    tag = "v${version}";
    hash = "sha256-5O+BGZCLP/bosTNMch8zy0mW0o4w296I/r03ZG1fu5I=";
  };

  # setup.py's LLAMA_CPP_COMMIT: ggml for the engines, mtmd for the image
  # encoder, gguf-py for the pack builders.
  llamaCpp = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "3cf03257f219afbe7334045ff7c6a06ac68c627d";
    hash = "sha256-SRGoXa+4ACBCB3eaG9XFYhMN1i0FyPEy9Rrer+dFGYI=";
  };

  engines = callPackage ./engines.nix {
    inherit
      src
      version
      llamaCpp
      gpuTargets
      ;
  };

  vision = callPackage ./vision.nix {
    inherit
      src
      version
      llamaCpp
      gpuTargets
      ;
  };

  # setup.py's PY_PACKAGES, less cmake and ninja, plus tokenizers for
  # DeepSeek's pack.
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
      jsonschema
      tokenizers
    ]
  );

  # The ROCm layout the setup's checks expect: llvm/bin/clang++ (clr's),
  # lib/libhipblas.so and bin/hipcc.
  rocm = symlinkJoin {
    name = "maya-rocm-${rocmPackages.clr.version}";
    paths = with rocmPackages; [
      clr
      hipblas
      hipblaslt
      rocblas
      rocm-smi
    ];
  };

  archsJson = builtins.toJSON gpuTargets;
in
stdenvNoCC.mkDerivation {
  pname = "maya";
  inherit version src;

  # The stamps hash the release's files byte for byte.
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall

    release=$out/share/maya/release
    mkdir -p $release $out/bin
    cp -r . $release
    ln -s ${llamaCpp} $release/third_party/llama.cpp

    mkdir -p $release/build-hip $release/build-vision/bin
    ln -s ${engines}/bin/{maya,maya-ds4,maya-mm3} $release/build-hip/
    ln -s ${vision}/bin/maya-vision $release/build-vision/bin/

    # Build stamps that tell the setup the engines are current, and the pip
    # stamp that tells it the Python packages are installed.
    ${lib.getExe pythonEnv} - $release <<'PY'
    import json, pathlib, sys
    root = pathlib.Path(sys.argv[1])
    sys.path.insert(0, str(root))
    import setup as S
    archs = json.loads('${archsJson}')
    llama = "${llamaCpp}"
    (root / "build-hip" / "MAYA-BUILD.json").write_text(json.dumps({
        "backend": "hip", "src": S.source_hash(S.ENGINE_SOURCES), "archs": archs,
        "rocm": "${rocm}", "gpu_ids": [0], "llama": llama, "lib_dirs": ["${rocm}/lib"],
        "date": "nixpkgs", "targets": ["maya", "maya-ds4", "maya-mm3"],
    }, indent=1))
    (root / "build-vision" / "MAYA-BUILD.json").write_text(json.dumps({
        "src": S.source_hash(("tools/vision",)), "archs": archs, "llama": llama,
        "backend": "hip", "date": "nixpkgs",
    }, indent=1))
    (root.parent / "pip-stamp.json").write_text(
        json.dumps(sorted(set(S.PY_PACKAGES) | {"tokenizers"})))
    PY

    install -m755 ${
      replaceVars ./launcher.sh {
        inherit runtimeShell rocm;
        out = null;
        python = lib.getExe pythonEnv;
        cc = stdenv.cc;
      }
    } $out/bin/maya
    substituteInPlace $out/bin/maya --replace-fail @out@ $out

    runHook postInstall
  '';

  passthru = {
    inherit
      engines
      vision
      llamaCpp
      rocm
      pythonEnv
      ;
  };

  meta = {
    description = "Inference engine and OpenAI/Anthropic-compatible server for GLM-5.3-Flash, DeepSeek-V4.1-Flash and MiniMax-M3.1-Flash";
    homepage = "https://github.com/mw00/project-maya";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "maya";
  };
}
