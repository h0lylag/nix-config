{
  description = "NixOS configuration for relic";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, unstable, ... }: {
    nixosConfigurations = {
      relic = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/relic.nix
          ({ config, pkgs, ... }: {
            nixpkgs.overlays = [
              (final: prev: {
                tailscale = (import unstable {
                  system = "x86_64-linux";
                  config.allowUnfree = true;
                }).tailscale;
              })
            ];
            # (You can keep your own settings here)
          })
        ];
      };
    };
  };
}
