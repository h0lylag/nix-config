{
  description = "NixOS configurations for h0lylag's infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    winapps.url = "github:winapps-org/winapps";
    winapps.inputs.nixpkgs.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";

    # Determinate Systems flake for Determinate Nix
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      disko,
      sops-nix,
      winapps,
      nix-gaming,
      nix-citizen,
      determinate,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {

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

            # Cachix binary caches for gaming inputs
            {
              nix.settings = {
                substituters = [
                  "https://nix-gaming.cachix.org"
                  "https://nix-citizen.cachix.org"
                ];
                trusted-public-keys = [
                  "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
                  "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="
                ];
              };
            }
          ];
        };

        # home server public facing machine
        coagulation = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            ./hosts/coagulation/default.nix
            sops-nix.nixosModules.sops
          ];
        };

        # Heztner-cloud VM (OVH datacenter)
        midship = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            ./hosts/midship/default.nix
            sops-nix.nixosModules.sops
          ];
        };

        # OVH dedicated server
        gemini = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            ./hosts/gemini/default.nix
            sops-nix.nixosModules.sops
          ];
        };

        # beavercreek host - IN TESTING - Replacement for proxmox home server
        # ZFS-based VM with disko disk management and nixos-containers
        beavercreek = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
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
