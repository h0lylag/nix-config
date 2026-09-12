{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.coagulation.instantiate =
    args:
    inputs.nixpkgs.lib.nixosSystem (
      args
      // {
        system = "x86_64-linux";
        specialArgs = (args.specialArgs or { }) // {
          inherit (inputs)
            nixpkgs-unstable
            determinate-nix
            NixVirt
            sops-nix
            nix-minecraft
            hermes-agent
            ;
        };
      }
    );

  den.aspects.coagulation = {
    includes = [
      den.aspects.base
      den.aspects.common
      den.aspects.coagulation-containers
    ];
    nixos.imports = [
      ../../hosts/coagulation/default.nix
      inputs.sops-nix.nixosModules.sops
      inputs.disko.nixosModules.disko
      inputs.NixVirt.nixosModules.default
    ];
  };
}
