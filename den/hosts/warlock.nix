{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.warlock = { };

  den.aspects.warlock = {
    includes = [
      den.aspects.base
      den.aspects.common
    ];

    nixos.imports = [
      ../../hosts/warlock/default.nix
      inputs.sops-nix.nixosModules.sops
    ];
  };
}
