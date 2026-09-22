{ inputs }:
{
  sources =
    _final: prev:
    let
      system = prev.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    in
    {
      stable = import inputs.nixpkgs { inherit system config; };
      unstable = import inputs.nixpkgs-unstable { inherit system config; };
    };
  local = import ./local.nix;

  tailscale = import ./replacements/tailscale.nix;

  bolt-launcher = import ./fixes/bolt-launcher.nix;
  libvirt-exporter = import ./fixes/prometheus-libvirt-exporter.nix;
}
