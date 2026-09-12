{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.backwash = { };

  den.aspects.backwash = {
    includes = [ den.aspects.desktop ];

    nixos.imports = [
      ../../hosts/backwash/default.nix
      inputs.sops-nix.nixosModules.sops
    ];
  };
}
