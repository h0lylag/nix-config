{
  lib,
  rustPlatform,
  desktop-file-utils,
  libGL,
  libxkbcommon,
  wayland,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
}:

let
  src = builtins.fetchGit {
    # git ls-remote ssh://git@github.com/Outback-Steakhouse-Of-Pancakes/rake.git main
    url = "ssh://git@github.com/Outback-Steakhouse-Of-Pancakes/rake.git";
    rev = "76ef79609b87e408d3f16d2f4f74683edaff3210";
  };

  # winit and glutin load these with dlopen, so the linker does not record them.
  runtimeLibraries = [
    libGL
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in

rustPlatform.buildRustPackage {
  pname = "ecm";
  version = "0.2.0-unstable-2026-10-26";

  inherit src;
  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoBuildFlags = [
    "-p"
    "ecm"
  ];

  # The tests would rebuild the workspace with the release profile's LTO.
  doCheck = false;

  nativeBuildInputs = [ desktop-file-utils ];

  postInstall = ''
    desktop-file-install --dir $out/share/applications ecm/assets/ecm.desktop
    mkdir -p $out/share/icons
    cp -r --no-preserve=mode ecm/assets/hicolor $out/share/icons/
  '';

  # An rpath rather than LD_LIBRARY_PATH, which would leak into the EVE
  # clients that ECM launches.
  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath runtimeLibraries} $out/bin/ecm
  '';

  meta = {
    description = "Utility";
    homepage = "https://github.com/Outback-Steakhouse-Of-Pancakes/rake";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
    mainProgram = "ecm";
  };
}
