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
      # Import our helper library
      lib = import ./lib { inherit inputs; };
    in
    {
      # Expose our lib for reuse
      inherit lib;

      nixosConfigurations = {

        # main desktop and gaming machine
        relic = lib.mkWorkstation "relic";

        # home server public facing machine
        coagulation = lib.mkServer "coagulation";

        # Heztner-cloud VM (OVH datacenter)
        midship = lib.mkServer "midship";

        # OVH dedicated server
        gemini = lib.mkServer "gemini";

        # beavercreek host - IN TESTING - Replacement for proxmox home server
        # ZFS-based VM with disko disk management and nixos-containers
        beavercreek = lib.mkTestServer "beavercreek";

      };
    };
}
