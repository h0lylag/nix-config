{ pkgs }:

let
  krisp-patch-all = pkgs.writeShellScriptBin "krisp-patch-all" (
    builtins.readFile ./krisp-patch-all.sh
  );

  krisp-patch =
    pkgs.writers.writePython3Bin "krisp-patch"
      {
        libraries = with pkgs.python3Packages; [
          capstone
          pyelftools
        ];
        flakeIgnore = [
          "E501"
          "F403"
          "F405"
        ];
      }
      (
        builtins.readFile (
          pkgs.fetchurl {
            url = "https://pastebin.com/raw/8tQDsMVd";
            sha256 = "sha256-IdXv0MfRG1/1pAAwHLS2+1NESFEz2uXrbSdvU9OvdJ8=";
          }
        )
      );
in
{
  krisp-patch-all = krisp-patch-all;
  krisp-patch = krisp-patch;
}
