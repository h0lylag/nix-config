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

  outputs = { self, nixpkgs, unstable, nix-gaming, nix-citizen, ... }: {
    nixosConfigurations = {
      relic = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hosts/relic.nix
          nix-citizen.nixosModules.StarCitizen

          ({ config, pkgs, ... }: {
            nixpkgs.overlays = [
              (final: prev: {

                # tailscale overlay
                tailscale = (import unstable {
                  system = "x86_64-linux";
                  config.allowUnfree = true;
                }).tailscale;
              })
            ];

            # nix-citizen Star Citizen module options
            nix-citizen.starCitizen = {
              enable = true;
              preCommands = ''
                export MANGOHUD=1;
                #unset DISPLAY;
              '';
              # setLimits = true; # uncomment to ensure sysctl tweaks (default true)
            };
          })
        ];
      };
    };
  };
}
