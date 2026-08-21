{ lib, python3Packages }:

python3Packages.buildPythonApplication {
  pname = "smartmon-helper";
  version = "0.1.0";
  pyproject = false;

  src = ./.;

  installPhase = ''
    install -Dm755 smartmon_helper.py $out/bin/smartmon-helper
  '';

  meta = with lib; {
    description = "Read-only smartctl snapshot collector";
    platforms = platforms.linux;
    mainProgram = "smartmon-helper";
  };
}
