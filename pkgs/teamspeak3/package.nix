{
  pkgs,
  nixpkgs-25-11,
}:

let
  legacyPkgs = import nixpkgs-25-11 {
    system = pkgs.stdenv.hostPlatform.system;
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "qtwebengine-5.15.19"
      ];
    };
  };
in

legacyPkgs.teamspeak3
