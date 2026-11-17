{
  lib,
  stdenv,
  cmake,
  ninja,
  python3,
  rocmPackages,
  src,
  version,
  llamaCpp,
  gpuTargets,
}:
let
  targets = lib.concatStringsSep ";" gpuTargets;
in
stdenv.mkDerivation {
  pname = "maya-vision";
  inherit src version;

  # maya-vision is llama.cpp's mtmd plus GLM-5.3-Flash's vision tower, which
  # the setup patches into its llama.cpp checkout.
  postUnpack = ''
    cp -r --no-preserve=mode ${llamaCpp} llama.cpp
    python3 $sourceRoot/tools/vision/glm5next_patch.py llama.cpp
  '';

  cmakeDir = "../tools/vision";

  nativeBuildInputs = [
    cmake
    ninja
    python3
    rocmPackages.clr
  ];

  buildInputs = with rocmPackages; [
    clr
    hipblas
    rocblas
  ];

  cmakeBuildType = "Release";

  # The flags maya.py's setup passes for the HIP image encoder.
  cmakeFlags = [
    (lib.cmakeBool "STRATA_VISION_HIP" true)
    (lib.cmakeBool "STRATA_PORTABLE" true)
    (lib.cmakeFeature "STRATA_VISION_HIP_TARGETS" targets)
    (lib.cmakeFeature "AMDGPU_TARGETS" targets)
    (lib.cmakeFeature "CMAKE_HIP_ARCHITECTURES" targets)
    (lib.cmakeFeature "CMAKE_HIP_COMPILER" "${rocmPackages.clr.hipClangPath}/clang++")
    (lib.cmakeFeature "CMAKE_EXE_LINKER_FLAGS" "-no-pie")
  ];

  preConfigure = ''
    appendToVar cmakeFlags "-DLLAMA_DIR=$NIX_BUILD_TOP/llama.cpp"
  '';

  ninjaFlags = [ "maya-vision" ];

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/maya-vision -t $out/bin
    runHook postInstall
  '';

  meta = {
    description = "Project Maya's HIP image encoder for GLM-5.3-Flash";
    homepage = "https://github.com/mw00/project-maya";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
