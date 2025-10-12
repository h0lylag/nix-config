# Star Citizen feature - Game-specific configuration
# Cachix settings are configured at the flake level in lib/default.nix
{
  config,
  pkgs,
  lib,
  specialArgs,
  ...
}:

let
  # Make it easier to refer to the flake inputs
  inputs = specialArgs;
in

{
  # Import the official nix-citizen StarCitizen module
  imports = [ inputs.nix-citizen.nixosModules.StarCitizen ];

  # Star Citizen configuration
  nix-citizen.starCitizen = {
    enable = true;

    # Commands to run before launching the game
    # EXPORT DISPLAY= is needed to run on wayland properly. if not set, the mouse doesnt stay locked in the game window
    preCommands = ''
      export MANGOHUD=1
      export DISPLAY=
    '';
  };
}
