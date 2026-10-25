final: _prev:
let
  # Every top-level pkgs/<name>/package.nix is part of pkgs.local. Discover
  # ordinary recipes from that layout so adding one does not require a second
  # catalogue entry; keep only package-set and argument exceptions below.
  discovered = final.lib.filesystem.packagesFromDirectoryRecursive {
    inherit (final) callPackage;
    directory = ../pkgs;
  };
in
{
  local = discovered // {
    # ECM needs Rust 1.99, newer than the stable package set's toolchain.
    ecm = final.unstable.callPackage ../pkgs/ecm/package.nix { };
    # This package uses libraries from the pinned unstable package set.
    imgcat-django = final.unstable.callPackage ../pkgs/imgcat-django/package.nix { };
  };
}
