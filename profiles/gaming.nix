# Gaming profile - Gaming-specific configuration and packages
# Import this in addition to workstation.nix for gaming machines
{
  config,
  lib,
  pkgs,
  eve-preview-manager,
  ...
}:

let
  eve-online = pkgs.callPackage ../pkgs/eve-online/default.nix { };
  jeveassets = pkgs.callPackage ../pkgs/jeveassets/default.nix { };
  py-eve-l-preview = pkgs.callPackage ../pkgs/py-eve-l-preview/default.nix { };
  dayz-tools = pkgs.callPackage ../pkgs/dayz-tools/default.nix { };
  jackify = pkgs.callPackage ../pkgs/jackify/default.nix { };
in

{
  imports = [
    ../features/star-citizen.nix
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
    steam-run
    protontricks
    bolt-launcher
    prismlauncher
    eve-online
    jeveassets
    py-eve-l-preview
    pyfa
    dayz-tools.a2s-info
    dayz-tools.xml-validator
    cubiomes-viewer
    eve-preview-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
    jackify
  ];
}
