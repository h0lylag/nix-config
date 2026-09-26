{ inputs, den, ... }:
let
  overlays = import ../../overlays { inherit inputs; };
in
{
  den.aspects.gaming.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    {
      nixpkgs.overlays = [
        inputs.nix-eve.overlays.default
        overlays.bolt-launcher
      ];

      # Gaming support - Steam with remote play
      programs.steam = {
        enable = lib.mkDefault true;
        remotePlay.openFirewall = lib.mkDefault true;
        dedicatedServer.openFirewall = lib.mkDefault false;
      };

      # Gaming packages
      environment.systemPackages = with pkgs; [
        mangohud
        gamescope
        protontricks
        bolt-launcher
        prismlauncher
        eve-online
        pkgs.local.cmel
        pkgs.local.evemon
        pkgs.local.jeveassets
        pyfa
        pkgs.local.dayz-tools.a2s-info
        pkgs.local.dayz-tools.xml-validator
        pkgs.local.rusty-shovel
        cubiomes-viewer
        inputs.eve-preview-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
        inputs.set-desto.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
