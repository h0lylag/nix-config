{ inputs, ... }:
let
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
in
{
  # Package tooling can evaluate these recipes without selecting a NixOS host.
  flake.packages.x86_64-linux.tunarr = pkgs.callPackage ../pkgs/tunarr/package.nix { };
}
