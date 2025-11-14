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

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";

    eve-l-preview-2.url = "github:ilveth/eve-l-preview";

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
      nix-minecraft,
      eve-l-preview-2,
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
              eve-l-preview-2
              ;
          };
          modules = [
            ./hosts/relic/default.nix
            sops-nix.nixosModules.sops
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
          specialArgs = {
            inherit nixpkgs-unstable nix-minecraft;
          };
          modules = [
            ./hosts/midship/default.nix
            sops-nix.nixosModules.sops
            nix-minecraft.nixosModules.minecraft-servers
            { nixpkgs.overlays = [ nix-minecraft.overlay ]; }
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

        # Oracle Cloud free tier VM
        warlock = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            ./hosts/warlock/default.nix
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
          ];
        };

      };
    };
}
