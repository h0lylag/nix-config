{
  lib,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "qbt-backup";
  version = "1.0.0";
  pyproject = false;

  src = ./.;

  installPhase = ''
    install -Dm755 qbt_backup.py $out/bin/qbt-backup
  '';

  meta = with lib; {
    description = "Backup script for qBittorrent instances";
    platforms = platforms.all;
  };
}
