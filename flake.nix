{
  description = "NixOS configuration for relic";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Gaming stuff
    nix-gaming.url = "github:fufexan/nix-gaming";

    # Star Citizen stuff
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";
  };

  outputs = { self, nixpkgs, unstable,  nix-citizen, nix-gaming, ... }: {
    nixosConfigurations = {
      relic = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          nix-citizen.nixosModules.StarCitizen
          {

            # use tailscale from unstable
            nixpkgs.overlays = [
              (final: prev: {
                tailscale = (import unstable {
                  system = "x86_64-linux";
                  config.allowUnfree = true;
                }).tailscale;
              })
            ];

            # Star Citizen stuff
            nix-citizen.starCitizen = {
              enable = true;
              preCommands = ''
                export MANGOHUD=1;
              '';
            };

            # Cache settings
            nix.settings = {
              substituters = [
                "https://nix-citizen.cachix.org"
                "https://nix-gaming.cachix.org"
              ];
              trusted-public-keys = [
                "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="
                "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
              ];
            };

          }
        ];
      };
    };
  };
}
