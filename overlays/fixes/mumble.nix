_final: prev: {
  # Mumble creates its Speex preprocessor inside PipeWire's realtime capture
  # callback. nixpkgs builds speexdsp against FFTW, which it plans with
  # FFTW_PATIENT; that overruns rtkit's 200 ms RLIMIT_RTTIME and the kernel
  # SIGKILLs Mumble on startup.
  mumble = prev.mumble.override {
    speexdsp = prev.speexdsp.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + "\n"
        + ''
          substituteInPlace libspeexdsp/fftwrap.c \
            --replace-fail FFTW_PATIENT FFTW_ESTIMATE
        '';
    });
  };
}
