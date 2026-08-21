{
  lib,
  python3,
  python3Packages,
}:

python3Packages.buildPythonApplication {
  pname = "cortana-briefing";
  version = "unstable-2026-08-20";
  format = "other";

  src = builtins.fetchGit {
    url = "https://github.com/h0lylag/cortana-briefing.git";
    rev = "7016e164edd8f1319ea61e28c028991e10b48445";
  };

  installPhase = ''
    install -Dm755 cortana-briefing.py "$out/bin/cortana-briefing"
    substituteInPlace "$out/bin/cortana-briefing" \
      --replace-fail "/usr/bin/env python3" "${python3}/bin/python3"
    if [[ -d collectors ]]; then
      install -d "$out/bin/collectors"
      install -m644 collectors/*.py "$out/bin/collectors/"
    fi
    install -Dm755 morning-context.sh "$out/bin/morning-context.sh"
  '';

  meta = with lib; {
    description = "Normalized morning-context collector for the Cortana Hermes agent";
    homepage = "https://github.com/h0lylag/cortana-briefing";
    platforms = platforms.linux;
    mainProgram = "cortana-briefing";
  };
}
