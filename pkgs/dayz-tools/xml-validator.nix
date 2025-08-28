{
  lib,
  stdenvNoCC,
  python3,
  src,
}:

stdenvNoCC.mkDerivation rec {
  pname = "xml-validator";
  version = "unstable";
  inherit src;

  nativeBuildInputs = [ python3 ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 ${src}/xml-validator.py $out/bin/${pname}

    patchShebangs $out/bin/${pname}

    runHook postInstall
  '';

  meta = with lib; {
    description = "xml-validator python script";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
