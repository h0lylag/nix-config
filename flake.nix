{
  description = "NixOS configuration for relic";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    winapps.url = "github:winapps-org/winapps";
    winapps.inputs.nixpkgs.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";

    # Determinate Systems flake for Determinate Nix
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      sops-nix,
      disko,
      nix-gaming,
      nix-citizen,
      determinate,
      winapps,
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
          specialArgs = {
            inherit
              nixpkgs-unstable
              nix-gaming
              nix-citizen
              winapps
              ;
          };
          modules = [
            ./hosts/relic/default.nix
            sops-nix.nixosModules.sops
          ];
        };

        # coagulation host
        # home server public facing machine
        coagulation = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            ./hosts/coagulation/default.nix
          ];
        };

        # midship host
        # Heztner-cloud VM (OVH datacenter)
        midship = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            ./hosts/midship/default.nix
          ];
        };

        # gemini host
        # OVH dedicated server
        gemini = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            ./hosts/gemini/default.nix
          ];
        };

        # beavercreek host - IN TESTING - Replacement for proxmox home server
        # ZFS-based VM with disko disk management
        beavercreek = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable sops-nix; };
          modules = [
            ./hosts/beavercreek/default.nix
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            determinate.nixosModules.default
          ];
        };

      };
    };
}
