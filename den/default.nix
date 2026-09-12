{ inputs, ... }:
{
  imports = [
    inputs.den.flakeModule
    ./schema.nix
    ../hosts/backwash/default.nix
    ../hosts/relic/default.nix
    ../hosts/warlock/default.nix
    ../hosts/ascension/default.nix
    ../hosts/midship/default.nix
    ../hosts/coagulation/default.nix
    ../hosts/coagulation/containers/den.nix
    ./aspects/container-base.nix
    ./aspects/tailscale.nix
    ./aspects/sops-age-key.nix
    ./aspects/star-citizen.nix
    ./aspects/base.nix
    ./aspects/common.nix
    ./aspects/workstation.nix
    ./aspects/plasma.nix
    ./aspects/pipewire.nix
    ./aspects/gaming.nix
    ./aspects/podman.nix
    ./aspects/desktop.nix
    ./aspects/nixcord.nix
  ];
}
