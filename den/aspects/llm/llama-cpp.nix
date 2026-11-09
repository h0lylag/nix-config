{ lib, pkgs, ... }:
let
  # Each file in ./models is a model preset: a set of llama-server flags that
  # clients select by name (the file name minus .nix is the preset id).
  #
  # The flags are tuned for relic's 24 GiB GPU. The presets set no -ngl, so
  # layer placement is left to llama.cpp's autofit: for the MoE presets it
  # keeps the attention path and KV cache in VRAM and leaves the expert
  # weights in system RAM.
  models =
    lib.mapAttrs'
      (file: _: lib.nameValuePair (lib.removeSuffix ".nix" file) (import (./models + "/${file}")))
      (
        lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".nix" file) (
          builtins.readDir ./models
        )
      );
in
{
  services.llama-cpp = {
    enable = true;

    # No model is set, so llama-server runs as a router: it starts with
    # nothing loaded and loads the preset a request names, on demand.
    #
    # Precedence is CLI > preset section > "*": these settings become
    # command-line arguments, which override the preset file, so keep them to
    # flags no preset should change. Per-model flags belong in ./models, and
    # defaults a preset may override belong in the "*" section below.
    settings = {
      # Binds every interface but is reachable only over the tailnet: the
      # firewall opens only tailscale0, keeping the LAN closed.
      host = "::";

      # VRAM fits one model, so a request for another unloads the idle one.
      models-max = 1;
      models-preset = pkgs.writeText "llama-cpp-models.ini" (
        lib.generators.toINIWithGlobalSection { } {
          globalSection.version = 1;
          sections = models // {
            "*" = {
              # Don't list a cached model that a preset covers, so a request
              # for it always loads through the preset, with its flags.
              dedup-cache-models = true;

              # The free-VRAM margin --fit leaves for the rest of the system.
              # The desktop and games share this GPU; at the default 1 GiB
              # margin their runtime buffers filled VRAM, KWin could not pin
              # framebuffers, and prompt processing stalled at 0.1 tok/s.
              fit-target = 4096;
            };
          };
        }
      );

      flash-attn = "on";
      parallel = 1;

      # Sleep after 15 idle minutes, unloading the model to free VRAM for the
      # desktop and games.
      sleep-idle-seconds = 900;
    };
  };
}
