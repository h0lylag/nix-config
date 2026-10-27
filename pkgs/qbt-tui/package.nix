{
  lib,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "qbt-tui";
  version = "1.0.0";
  pyproject = false;

  src = ./.;

  installPhase = ''
    install -Dm755 qbt_tui.py $out/bin/qbt-tui
  '';

  meta = with lib; {
    description = "Terminal manager for several qBittorrent instances";
    mainProgram = "qbt-tui";
    platforms = platforms.all;
  };
}
