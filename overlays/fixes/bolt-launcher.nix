final: prev: {
  # Wine helpers consume multiple ALSA devices. If snd_aloop is loaded, the
  # Loopback card can become hw:0 and Java audio plays into a dead end.
  # Route ALSA's default device through the PulseAudio plugin into PipeWire.
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
          # ALSA_CONFIG_PATH replaces the entire config, so load its normal
          # definitions before overriding only the default devices. Keep the
          # Pulse property override because RuneLite otherwise has a generic
          # name in the audio mixer.
          profile = (args.profile or "") + ''
            export ALSA_PLUGIN_DIR=/usr/lib/alsa-lib
            export ALSA_CONFIG_PATH=${final.writeText "asound-pulse.conf" ''
              <${final.alsa-lib}/share/alsa/alsa.conf>
              pcm.!default { type pulse }
              ctl.!default { type pulse }
            ''}
            export PULSE_PROP_OVERRIDE="application.name='RuneLite' application.icon_name='runelite'"
          '';
        }
      );
  };
}
