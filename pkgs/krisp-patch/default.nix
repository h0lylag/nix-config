{ pkgs }:

# discord: krisp module doesn't load #195512
# https://github.com/NixOS/nixpkgs/issues/195512

{
  krisp-patch-all = pkgs.writers.writePython3Bin "krisp-patch-all" {
    libraries = with pkgs.python3Packages; [ ];
    flakeIgnore = [
      "E501" # Line too long
    ];
  } (builtins.readFile ./krisp-patch-all.py);

  krisp-patch = pkgs.writers.writePython3Bin "krisp-patch" {
    libraries = with pkgs.python3Packages; [
      capstone
      pyelftools
    ];
    flakeIgnore = [
      "E501" # Line too long
      "F403" # 'from module import *' used; unable to detect undefined names
      "F405" # Name may be undefined, or defined from star imports
    ];
  } (builtins.readFile ./krisp-patch.py);
}
