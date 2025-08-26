{
  lib,
  pkgs,
  python3,
}:

let
  # Keep this in one place so you can reuse for other tools
  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/dayz-tools.git";
    rev = "853713ceee0d171c54fe832cdae0cdf059b40164";
  };
in
{
  dayz-a2s = pkgs.callPackage ./a2s.nix {
    inherit lib python3 src;
    stdenvNoCC = pkgs.stdenvNoCC;
  };
}
