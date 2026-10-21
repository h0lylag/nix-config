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

  bolt-launcher = import ./fixes/bolt-launcher.nix;
  libvirt-exporter = import ./fixes/prometheus-libvirt-exporter.nix;
  v4l2loopback = import ./fixes/v4l2loopback.nix;

  php = import ./replacements/php.nix { inherit inputs; };
}
