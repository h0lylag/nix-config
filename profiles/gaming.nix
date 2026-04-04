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
  dayz-tools = pkgs.callPackage ../pkgs/dayz-tools/default.nix { };

  # Re-wrap bolt-launcher to force ALSA through PulseAudio plugin → PipeWire.
  # If snd_aloop is loaded, the Loopback card becomes hw:0 and Java's ALSA sound engine
  # picks it instead of a real output — audio plays into a dead-end and nothing reaches
  # PipeWire. Forcing type pulse bypasses ALSA device enumeration entirely and routes
  # directly through PipeWire's PulseAudio compat socket.
  bolt-launcher = pkgs.bolt-launcher.override {
    buildFHSEnv =
      args:
      pkgs.buildFHSEnv (
        args
        // {
          targetPkgs =
            pkgs':
            (args.targetPkgs pkgs')
            ++ [
              pkgs'.alsa-lib
              pkgs'.alsa-plugins
            ];
          profile = (args.profile or "") + ''
            export ALSA_PLUGIN_DIR=/usr/lib/alsa-lib
            export ALSA_CONFIG_PATH=${pkgs.writeText "asound-pulse.conf" ''
              pcm.!default { type pulse }
              ctl.!default { type pulse }
            ''}
          '';
        }
      );
  };
in

{
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
    jeveassets
    pyfa
    dayz-tools.a2s-info
    dayz-tools.xml-validator
    cubiomes-viewer
    # eve-preview-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
    (pkgs.callPackage ../pkgs/eve-preview-manager/package.nix { })
    (pkgs.callPackage ../pkgs/evebuddy/package.nix { })
  ];
}
