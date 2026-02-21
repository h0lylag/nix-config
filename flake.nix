{
  description = "NixOS configurations for h0lylag's infrastructure";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs-unstable.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    NixVirt.url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
    NixVirt.inputs.nixpkgs.follows = "nixpkgs";

    eve-preview-manager.url = "https://flakehub.com/f/h0lylag/EVE-Preview-Manager/*";
    eve-preview-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";

    antigravity-nix.url = "github:jacopone/antigravity-nix";
    antigravity-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      determinate,
      sops-nix,
      disko,
      NixVirt,
      eve-preview-manager,
      nix-gaming,
      nix-citizen,
      nix-minecraft,
      antigravity-nix,
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
              nixpkgs
              nixpkgs-unstable
              eve-preview-manager
              nix-gaming
              nix-citizen
              antigravity-nix
              ;
          };
          modules = [
            ./hosts/relic/default.nix
            determinate.nixosModules.default
            sops-nix.nixosModules.sops
          ];
        };

        # home server public facing machine
        lockout = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            ./hosts/lockout/default.nix
            determinate.nixosModules.default
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
            determinate.nixosModules.default
            sops-nix.nixosModules.sops
            nix-minecraft.nixosModules.minecraft-servers
            { nixpkgs.overlays = [ nix-minecraft.overlay ]; }
          ];
        };

        # coagulation host - home server
        coagulation = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable NixVirt sops-nix nix-minecraft; };
          modules = [
            ./hosts/coagulation/default.nix
            determinate.nixosModules.default
            sops-nix.nixosModules.sops
            disko.nixosModules.disko
            NixVirt.nixosModules.default
          ];
        };

        # Oracle Cloud free tier VM
        warlock = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixpkgs-unstable; };
          modules = [
            ./hosts/warlock/default.nix
            determinate.nixosModules.default
            sops-nix.nixosModules.sops
            disko.nixosModules.disko
          ];
        };
      };
    };
}
