{
  lib,
  pkgs,
  python3 ? pkgs.python3,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "reddit-watchexchange-monitor";
  version = "1.0.0";

  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/reddit-json.git";
    rev = "84ef987ab2894960a8353dfddbb295bca14b9f84";
  };

  pyproject = true;

  build-system = with python3.pkgs; [
    setuptools
  ];

  dependencies = with python3.pkgs; [
    requests
  ] ++ lib.optionals (python3.pythonOlder "3.11") [
    tomli
  ];

  doCheck = false;

  meta = with lib; {
    description = "Monitor r/Watchexchange for new posts and send Discord notifications";
    homepage = "https://github.com/h0lylag/reddit-json";
    license = licenses.mit;
    mainProgram = "fetch-posts";
  };
}
