# Container configurations for coagulation
{
  config,
  pkgs,
  lib,
  sops-nix,
  ...
}:

{
  # Enable container support
  boot.enableContainers = true;

  # Common container parameters
  # All containers use bridge networking with br0
  # All containers get their own MAC and DHCP lease
  # All containers are set to not autostart by default

  # The nested container evaluator does not inherit the host's specialArgs.
  # Pass the shared flake input to every declarative container once here.
  containers =
    lib.genAttrs
      [
        "5teak"
        "cortana"
        "imgcat"
        "lmdaf-auth"
        "lockout"
        "minecraft"
        "sanctuary"
        "satisfactory"
        "tombstone"
        "uplift"
        "waterworks"
      ]
      (_: {
        specialArgs = { inherit sops-nix; };
      });

  # Import individual container configurations
  imports = [
    ./5teak
    ./cortana
    #./zanzibar
    ./imgcat
    ./lmdaf-auth
    ./lockout
    ./minecraft
    ./sanctuary
    ./satisfactory
    ./tombstone
    ./uplift
    ./waterworks
  ];
}
