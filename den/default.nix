{ inputs, ... }:
{
  imports = [
    inputs.den.flakeModule
    ./schema.nix
    ./hosts/backwash.nix
    ./hosts/relic.nix
    ./hosts/warlock.nix
    ./hosts/ascension.nix
    ./hosts/midship.nix
    ./hosts/coagulation.nix
    ./hosts/coagulation-containers.nix
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
