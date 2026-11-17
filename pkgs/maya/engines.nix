{
  lib,
  stdenv,
  cmake,
  ninja,
  rocmPackages,
  src,
  version,
  llamaCpp,
  gpuTargets,
}:
stdenv.mkDerivation {
  pname = "maya-engines";
  inherit src version;

  nativeBuildInputs = [
    cmake
    ninja
    rocmPackages.clr
  ];

  buildInputs = with rocmPackages; [
    clr
    hipblas
    hipblaslt
    rocblas
    rocwmma
  ];

  cmakeBuildType = "Release";

  # The flags maya.py's HIP setup passes, plus STRATA_PORTABLE so ggml's CPU
  # code is not built for the build machine's CPU. Maya picks its own AVX-512
  # kernels at run time either way.
  cmakeFlags = [
    (lib.cmakeBool "STRATA_ENABLE_HIP" true)
    (lib.cmakeBool "STRATA_ENABLE_CUDA" false)
    (lib.cmakeBool "STRATA_PREFILL_MMQ" true)
    (lib.cmakeBool "STRATA_NATIVE_EXPERTS" true)
    (lib.cmakeBool "STRATA_BUILD_TESTS" false)
    (lib.cmakeBool "STRATA_PORTABLE" true)
    (lib.cmakeFeature "CMAKE_HIP_ARCHITECTURES" (lib.concatStringsSep ";" gpuTargets))
    (lib.cmakeFeature "CMAKE_HIP_COMPILER" "${rocmPackages.clr.hipClangPath}/clang++")
    # The HIP compiler is not the cc-wrapper, so buildInputs' include paths
    # do not reach it.
    (lib.cmakeFeature "CMAKE_HIP_FLAGS" "-I${rocmPackages.rocwmma}/include")
    (lib.cmakeFeature "STRATA_GGML_DIR" "${llamaCpp}")
    (lib.cmakeFeature "MAYA_BUILD_ID" "v${version}")
  ];

  # One engine each for GLM-5.3-Flash (and Qwen), DeepSeek-V4.1-Flash and
  # MiniMax-M3.1-Flash.
  ninjaFlags = [
    "maya"
    "maya-ds4"
    "maya-mm3"
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 maya maya-ds4 maya-mm3 -t $out/bin
    runHook postInstall
  '';

  meta = {
    description = "Project Maya's HIP inference engines";
    homepage = "https://github.com/mw00/project-maya";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
