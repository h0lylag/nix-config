{ inputs, den, ... }:
let
  # Only active NixOS containers. Zanzibar remains disabled.
  containerModules = {
    "5teak" = ../../hosts/coagulation/containers/5teak;
    "cortana" = ../../hosts/coagulation/containers/cortana;
    "imgcat" = ../../hosts/coagulation/containers/imgcat;
    "lmdaf-auth" = ../../hosts/coagulation/containers/lmdaf-auth;
    "lockout" = ../../hosts/coagulation/containers/lockout;
    "minecraft" = ../../hosts/coagulation/containers/minecraft;
    "sanctuary" = ../../hosts/coagulation/containers/sanctuary;
    "satisfactory" = ../../hosts/coagulation/containers/satisfactory;
    "tombstone" = ../../hosts/coagulation/containers/tombstone;
    "uplift" = ../../hosts/coagulation/containers/uplift;
    "waterworks" = ../../hosts/coagulation/containers/waterworks;
  };
in
{
  den.aspects.coagulation-containers.nixos = { lib, ... }: {
    boot.enableContainers = true;
    imports = builtins.attrValues containerModules;
    # Container configuration is a separate NixOS evaluation. Select its shared
    # class module explicitly and supply the input used by the Tailscale module.
    containers = lib.mapAttrs (_: _: {
      specialArgs = { inherit (inputs) nixpkgs-unstable; };
      config.imports = [ den.aspects.container-base.nixos ];
    }) containerModules;
  };
}
