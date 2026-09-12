{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.relic = {
    nixpkgs = inputs.nixpkgs-unstable;
    specialArgs = { inherit (inputs) nixpkgs llm-agents; };
  };

  den.aspects.relic = {
    includes = [
      den.aspects.desktop
      den.aspects.star-citizen
    ];

    nixos.imports = [
      ../../hosts/relic/default.nix
      inputs.codex-desktop-linux.nixosModules.default
      inputs.sops-nix.nixosModules.sops
    ];
  };
}
