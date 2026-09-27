{ inputs, ... }:
let
  overlays = import ../overlays { inherit inputs; };
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
    overlays = [
      overlays.sources
      overlays.local
    ];
  };
in
{
  # Keep the full local set lazy: some entries are nested package sets rather
  # than derivations. Reuse the overlay's discovery and package-set exceptions.
  flake.legacyPackages.x86_64-linux = pkgs.local;
  flake.packages.x86_64-linux.tunarr = pkgs.local.tunarr;
}
