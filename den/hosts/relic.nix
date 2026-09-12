{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.relic.instantiate =
    args:
    inputs.nixpkgs-unstable.lib.nixosSystem (
      args
      // {
        system = "x86_64-linux";
        specialArgs = (args.specialArgs or { }) // {
          inherit (inputs)
            nixpkgs
            nixpkgs-unstable
            nixpkgs-25-11
            determinate-nix
            eve-preview-manager
            set-desto
            nix-gaming
            nix-citizen
            antigravity-nix
            llm-agents
            ;
        };
      }
    );

  den.aspects.relic = {
    includes = [ den.aspects.desktop ];

    nixos.imports = [
      ../../hosts/relic/default.nix
      inputs.codex-desktop-linux.nixosModules.default
      inputs.sops-nix.nixosModules.sops
    ];
  };
}
