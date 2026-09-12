{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.midship.instantiate =
    args:
    inputs.nixpkgs.lib.nixosSystem (
      args
      // {
        system = "x86_64-linux";
        specialArgs = (args.specialArgs or { }) // {
          inherit (inputs) nixpkgs-unstable determinate-nix eve-price-check;
        };
      }
    );

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
