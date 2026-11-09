{ inputs }:
let
  # python3Packages.dirhash (harbor's only missing runtime dep) is not in
  # nixpkgs; carry it in our own sets.
  python-dirhash = _final: prev: {
    python3Packages = prev.python3Packages.override (old: {
      overrides = prev.lib.composeExtensions (old.overrides or (_: _: { })) (
        self: super: {
          dirhash = self.callPackage ./python3-packages/dirhash/package.nix { };
        }
      );
    });
  };
in
{
  sources =
    _final: prev:
    let
      system = prev.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    in
    {
      stable = import inputs.nixpkgs { inherit system config; };
      unstable = import inputs.nixpkgs-unstable {
        inherit system config;
        overlays = [ python-dirhash ];
      };
    };
  local = import ./local.nix;

  bolt-launcher = import ./fixes/bolt-launcher.nix;
  mumble = import ./fixes/mumble.nix;
  trayscale = import ./fixes/trayscale.nix;
  v4l2loopback = import ./fixes/v4l2loopback.nix;

  php = import ./replacements/php.nix { inherit inputs; };
}
