{ den, ... }:
let
  # Only active NixOS containers. Zanzibar remains disabled.
  containerModules = {
    "5teak" = ./5teak;
    "cortana" = ./cortana;
    "imgcat" = ./imgcat;
    "lmdaf-auth" = ./lmdaf-auth;
    "lockout" = ./lockout;
    "minecraft" = ./minecraft;
    "sanctuary" = ./sanctuary;
    "satisfactory" = ./satisfactory;
    "tombstone" = ./tombstone;
    "uplift" = ./uplift;
    "waterworks" = ./waterworks;
  };
in
{
  den.aspects.coagulation-containers.nixos = { lib, ... }: {
    boot.enableContainers = true;
    imports = builtins.attrValues containerModules;
    # Container configuration is a separate NixOS evaluation. Select its shared
    # class module explicitly; shared aspects capture their own flake inputs.
    containers = lib.mapAttrs (_: _: {
      config.imports = [ den.aspects.container-base.nixos ];
    }) containerModules;
  };
}
