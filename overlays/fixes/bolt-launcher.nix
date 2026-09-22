final: prev: {
  # Wine helpers consume multiple ALSA devices. If snd_aloop is loaded, the
  # Loopback card can become hw:0 and Java audio plays into a dead end.
  # Force ALSA through the PulseAudio plugin into PipeWire instead.
  bolt-launcher = prev.bolt-launcher.override {
    buildFHSEnv =
      args:
      final.buildFHSEnv (
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
            export ALSA_CONFIG_PATH=${final.writeText "asound-pulse.conf" ''
              pcm.!default { type pulse }
              ctl.!default { type pulse }
            ''}
            export PULSE_PROP_OVERRIDE="application.name='RuneLite' application.icon_name='runelite'"
          '';
        }
      );
  };
}
