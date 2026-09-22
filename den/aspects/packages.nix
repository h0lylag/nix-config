{ inputs, den, ... }:
let
  overlays = import ../../overlays { inherit inputs; };
in
{
  den.aspects.packages.nixos =
    { ... }:
    {
      nixpkgs.overlays = [
        overlays.sources
        overlays.local
      ];
    };
}
