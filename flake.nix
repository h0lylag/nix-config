{
  description = "NixOS configurations for h0lylag's infrastructure";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixpkgs-unstable.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    den.url = "github:denful/den/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d";

    colmena.url = "github:nix-community/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs-unstable";
    colmena.inputs.stable.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-unstable.url = "github:nix-community/home-manager";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    determinate-nix.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    NixVirt.url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
    NixVirt.inputs.nixpkgs.follows = "nixpkgs";

    eve-preview-manager.url = "https://flakehub.com/f/h0lylag/EVE-Preview-Manager/*";
    eve-preview-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-eve.url = "github:h0lylag/nix-eve";
    nix-eve.inputs.nixpkgs.follows = "nixpkgs-unstable";

    set-desto.url = "https://flakehub.com/f/h0lylag/set-desto/*";
    set-desto.inputs.nixpkgs.follows = "nixpkgs";

    eve-price-check.url = "git+ssh://git@github.com/h0lylag/eve-price-check.git";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";

    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";

    antigravity-nix.url = "github:jacopone/antigravity-nix";
    antigravity-nix.inputs.nixpkgs.follows = "nixpkgs";

    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.8.19";

    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs-unstable";

    codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";
    codex-desktop-linux.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nixcord.url = "github:4evy/nixcord";
  };

  outputs =
    inputs:
    builtins.removeAttrs
      (inputs.nixpkgs.lib.evalModules {
        specialArgs = { inherit inputs; };
        modules = [ ./den/default.nix ];
      }).config.flake
      # This system flake does not publish a Den namespace library.
      [ "denful" ];
}
