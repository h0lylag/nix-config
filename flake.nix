{
  description = "NixOS configuration for relic";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      disko,
      nix-gaming,
      nix-citizen,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {

        # relic host
        # main desktop and gaming machine
        relic = nixpkgs-unstable.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nix-gaming nix-citizen nixpkgs-unstable; };
          # Updated path after moving relic.nix into hosts/relic/default.nix
          modules = [ ./hosts/relic/default.nix ];
        };

        # coagulation host
        # home server public facing machine
        coagulation = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [ ./hosts/coagulation/default.nix ];
        };

        # midship host
        # Heztner-cloud VM (OVH datacenter)
        midship = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [ ./hosts/midship/default.nix ];
        };

        # gemini host
        # OVH dedicated server
        gemini = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [ ./hosts/gemini/default.nix ];
        };

        # beavercreek host - IN TESTING - Replacement for proxmox home server
        # ZFS-based VM with disko disk management
        beavercreek = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            disko.nixosModules.disko
            ./hosts/beavercreek/default.nix
          ];
        };

      };
    };
}
