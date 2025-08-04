{ lib, callPackage, ... }:

{
  # Binary version (default, recommended for most users)
  binary = callPackage ./binary.nix { };

  # Source version (builds from GitHub using Maven)
  # Note: May require network access for Maven dependencies
  source = callPackage ./source.nix { };

  # Default to binary version
  default = callPackage ./binary.nix { };
}
