{ inputs, den, ... }:
{
  imports = [
    inputs.den.flakeModule
    ./aspects/base.nix
    ./aspects/common.nix
    ./aspects/workstation.nix
    ./aspects/plasma.nix
    ./aspects/pipewire.nix
    ./aspects/gaming.nix
    ./aspects/podman.nix
    ./aspects/desktop.nix
    ./aspects/nixcord.nix
  ];

  den.hosts.x86_64-linux.backwash.instantiate =
    args:
    inputs.nixpkgs.lib.nixosSystem (
      args
      // {
        system = "x86_64-linux";
        specialArgs = (args.specialArgs or { }) // {
          inherit (inputs)
            nixpkgs
            nixpkgs-unstable
            nixpkgs-25-11
            determinate-nix
            antigravity-nix
            eve-preview-manager
            set-desto
            ;
        };
      }
    );

  den.aspects.backwash = {
    includes = [ den.aspects.desktop ];

    nixos.imports = [
      ../hosts/backwash/default.nix
      inputs.sops-nix.nixosModules.sops
    ];
  };

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
      ../hosts/relic/default.nix
      inputs.codex-desktop-linux.nixosModules.default
      inputs.sops-nix.nixosModules.sops
    ];
  };

  den.hosts.x86_64-linux.warlock.instantiate =
    args:
    inputs.nixpkgs.lib.nixosSystem (
      args
      // {
        system = "x86_64-linux";
        specialArgs = (args.specialArgs or { }) // {
          inherit (inputs) nixpkgs-unstable determinate-nix;
        };
      }
    );

  den.aspects.warlock = {
    includes = [
      den.aspects.base
      den.aspects.common
    ];

    nixos.imports = [
      ../hosts/warlock/default.nix
      inputs.sops-nix.nixosModules.sops
    ];
  };

  den.hosts.x86_64-linux.ascension.instantiate =
    args:
    inputs.nixpkgs.lib.nixosSystem (
      args
      // {
        system = "x86_64-linux";
        specialArgs = (args.specialArgs or { }) // {
          inherit (inputs) nixpkgs-unstable determinate-nix;
        };
      }
    );

  den.aspects.ascension = {
    includes = [
      den.aspects.base
      den.aspects.common
    ];

    nixos.imports = [
      ../hosts/ascension/default.nix
      inputs.sops-nix.nixosModules.sops
      inputs.disko.nixosModules.disko
    ];
  };
}
