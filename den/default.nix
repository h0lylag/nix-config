{ inputs, den, ... }:
{
  den.schema.host.includes = [
    den.batteries.hostname
    den.aspects.base
  ];

  imports = [
    inputs.den.flakeModule
    ./schema.nix
    ./colmena.nix
    ../users/chris/default.nix
    ../hosts/backwash/default.nix
    ../hosts/343-guilty-spark/default.nix
    ../hosts/relic/default.nix
    ../hosts/001-shamed-instrument/default.nix
    ../hosts/007-contrite-witness/default.nix
    ../hosts/049-abject-testament/default.nix
    ../hosts/2401-penitent-tangent/default.nix
    ../hosts/16807-abashed-eulogy/default.nix
    ../hosts/117649-despondent-pyre/default.nix
    ../hosts/warlock/default.nix
    ../hosts/turf/default.nix
    ../hosts/ascension/default.nix
    ../hosts/midship/default.nix
    ../hosts/coagulation/default.nix
    ../hosts/coagulation/containers/den.nix
    ./aspects/container-base.nix
    ./aspects/packages.nix
    ./aspects/tailscale.nix
    ./aspects/sops-age-key.nix
    ./aspects/star-citizen.nix
    ./aspects/base.nix
    ./aspects/common.nix
    ./aspects/distributed-build-client.nix
    ./aspects/m75q.nix
    ./aspects/workstation.nix
    ./aspects/plasma.nix
    ./aspects/xfce.nix
    ./aspects/pipewire.nix
    ./aspects/gaming.nix
    ./aspects/podman.nix
    ./aspects/desktop.nix
    ./aspects/nixcord.nix
  ];
}
