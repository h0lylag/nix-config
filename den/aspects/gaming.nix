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
      nixpkgs.overlays = [ overlays.bolt-launcher ];

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
        pkgs.local.eve-online
        pkgs.local.evemon
        pkgs.local.jeveassets
        pkgs.local.rift
        pyfa
        pkgs.local.dayz-tools.a2s-info
        pkgs.local.dayz-tools.xml-validator
        pkgs.local.rusty-shovel
        cubiomes-viewer
        inputs.set-desto.packages.${pkgs.stdenv.hostPlatform.system}.default
        # Keep using the flake input; the local recipe is also registered.
        inputs.eve-preview-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
        inputs.set-desto.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
