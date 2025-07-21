{
  description = "NixOS configuration for relic";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";
  };

  outputs =
    {
      self,
      nixpkgs,
      unstable,
      nix-gaming,
      nix-citizen,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {
        relic = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nix-gaming nix-citizen unstable; };

          # import modules
          modules = [
            ./hosts/relic.nix
            ./modules/common.nix
            ./modules/desktop.nix
            ./modules/tailscale.nix
            ./modules/star-citizen.nix
          ];
        };
      };
    };
}
