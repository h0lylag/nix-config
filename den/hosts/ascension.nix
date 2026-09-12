{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.ascension = { };

  den.aspects.ascension = {
    includes = [
      den.aspects.base
      den.aspects.common
    ];

    nixos.imports = [
      ../../hosts/ascension/default.nix
      inputs.sops-nix.nixosModules.sops
      inputs.disko.nixosModules.disko
    ];
  };
}
