{
  lib,
  pkgs,
  python3,
}:

let
  # Keep this in one place so you can reuse for other tools
  src = builtins.fetchGit {
    url = "git@github.com:h0lylag/dayz-tools.git";
    rev = "43d8cf15a19b7f082d979b2ef56043f88754e79d";
  };
in
{
  dayz-a2s = pkgs.callPackage ./a2s.nix {
    inherit lib python3 src;
    stdenvNoCC = pkgs.stdenvNoCC;
  };
  dayz-xml = pkgs.callPackage ./xml-validator.nix {
    inherit lib python3 src;
    stdenvNoCC = pkgs.stdenvNoCC;
  };
}
