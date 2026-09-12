{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.midship.specialArgs = { inherit (inputs) eve-price-check; };

  den.aspects.midship = {
    includes = [
      den.aspects.base
      den.aspects.common
    ];

    nixos.imports = [
      ../../hosts/midship/default.nix
      inputs.sops-nix.nixosModules.sops
      inputs.disko.nixosModules.disko
    ];
  };
}
