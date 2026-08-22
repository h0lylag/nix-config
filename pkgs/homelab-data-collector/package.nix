{
  lib,
  python3Packages,
}:

python3Packages.buildPythonApplication rec {
  pname = "homelab-data-collector";
  version = "0.1.0";

  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/homelab-data-collector.git";
    rev = "5067266adfa6517ccd2e36d9b3b8f75a1f5a1996";
  };

  pyproject = true;

  build-system = [ python3Packages.setuptools ];
  dependencies = [ python3Packages.sqlalchemy ];

  doCheck = false;

  meta = with lib; {
    description = "Homelab collectors, state storage, and Hermes reports";
    homepage = "https://github.com/h0lylag/homelab-data-collector";
    platforms = platforms.linux;
    mainProgram = "hldc";
  };
}
