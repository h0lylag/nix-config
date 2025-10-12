# Gaming profile - Gaming-specific configuration and packages
# Import this in addition to workstation.nix for gaming machines
{
  config,
  lib,
  pkgs,
  ...
}:

let
  eve-online = pkgs.callPackage ../pkgs/eve-online/default.nix { };
  jeveassets = pkgs.callPackage ../pkgs/jeveassets/default.nix { };
  eve-l-preview = pkgs.callPackage ../pkgs/eve-l-preview/default.nix { };
  dayz-tools = pkgs.callPackage ../pkgs/dayz-tools/default.nix { };
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
    eve-l-preview
    pyfa
    dayz-tools.a2s-info
    dayz-tools.xml-validator
    cubiomes-viewer
  ];
}
