{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.warlock.instantiate =
    args:
    inputs.nixpkgs.lib.nixosSystem (
      args
      // {
        system = "x86_64-linux";
        specialArgs = (args.specialArgs or { }) // {
          inherit (inputs) nixpkgs-unstable determinate-nix;
        };
      }
    );

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
