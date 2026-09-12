{ inputs, ... }:
{
  imports = [
    inputs.den.flakeModule
    ./hosts/backwash.nix
    ./hosts/relic.nix
    ./hosts/warlock.nix
    ./hosts/ascension.nix
    ./hosts/midship.nix
    ./hosts/coagulation.nix
    ./hosts/coagulation-containers.nix
    ./aspects/container-base.nix
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
