{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.backwash.instantiate =
    args:
    inputs.nixpkgs.lib.nixosSystem (
      args
      // {
        system = "x86_64-linux";
        specialArgs = (args.specialArgs or { }) // {
          inherit (inputs)
            nixpkgs
            nixpkgs-unstable
            nixpkgs-25-11
            determinate-nix
            antigravity-nix
            eve-preview-manager
            set-desto
            ;
        };
      }
    );

  den.aspects.backwash = {
    includes = [ den.aspects.desktop ];

    nixos.imports = [
      ../../hosts/backwash/default.nix
      inputs.sops-nix.nixosModules.sops
    ];
  };
}
