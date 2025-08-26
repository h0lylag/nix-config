{
  lib,
  stdenvNoCC,
  python3,
  src,
}:

stdenvNoCC.mkDerivation rec {
  pname = "a2s";
  version = "unstable";
  inherit src;

  nativeBuildInputs = [ python3 ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # install the script and make it runnable
    install -Dm755 ${src}/a2s.py $out/bin/${pname}

    # if a2s.py has "#!/usr/bin/env python3", this rewrites it to the nix-store python
    patchShebangs $out/bin/${pname}

    runHook postInstall
  '';

  meta = with lib; {
    description = "A2S Python script";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
