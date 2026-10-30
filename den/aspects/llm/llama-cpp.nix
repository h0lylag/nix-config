{ lib, pkgs, ... }:
let
  # Each file in ./models is a preset that clients select by its file name.
  # Its keys are llama-server flags tuned for relic's 16 GiB GPU. Without GPU
  # layer flags, --fit keeps attention and KV in VRAM and moves the MoE
  # experts to RAM.
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

    # With no model set, llama-server runs as a router that starts a preset on
    # its first request. Presets inherit these flags, and these flags override
    # preset values, so model-specific flags belong in ./models.
    settings = {
      # Reachable only over the tailnet: the firewall trusts tailscale0 and
      # keeps the LAN closed.
      host = "::";

      # VRAM fits one model, so a request for another unloads the idle one.
      models-max = 1;
      models-preset = pkgs.writeText "llama-cpp-models.ini" (
        lib.generators.toINIWithGlobalSection { } {
          globalSection.version = 1;
          sections = models // {
            # Hide cached downloads that a preset covers, so they cannot load
            # without its flags.
            "*".dedup-cache-models = true;
          };
        }
      );

      flash-attn = "on";
      parallel = 1;

      # Free VRAM for games after 15 minutes
      sleep-idle-seconds = 900;
    };
  };
}
