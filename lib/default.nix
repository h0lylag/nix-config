{ inputs }:
{
  # Base system builder with common patterns
  mkSystem =
    {
      hostname,
      nixpkgs ? inputs.nixpkgs, # Default to stable
      system ? "x86_64-linux",
      extraSpecialArgs ? { },
      extraModules ? [ ],
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        # All systems get access to nixpkgs-unstable
        inherit (inputs) nixpkgs-unstable;
      }
      // extraSpecialArgs;

      modules = [
        ../hosts/${hostname}/default.nix
        inputs.sops-nix.nixosModules.sops
      ]
      ++ extraModules;
    };

  # Workstation/gaming host - uses unstable, includes gaming inputs
  mkWorkstation =
    hostname:
    inputs.self.lib.mkSystem {
      inherit hostname;
      nixpkgs = inputs.nixpkgs-unstable;
      extraSpecialArgs = {
        inherit (inputs) nix-gaming nix-citizen winapps;
      };
    };

  # Standard server host - stable nixpkgs
  mkServer = hostname: inputs.self.lib.mkSystem { inherit hostname; };

  # Server with disko and determinate (for future hosts)
  mkTestServer =
    hostname:
    inputs.self.lib.mkSystem {
      inherit hostname;
      extraModules = [
        inputs.disko.nixosModules.disko
        inputs.determinate.nixosModules.default
      ];
    };
}
