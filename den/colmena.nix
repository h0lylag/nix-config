{
  inputs,
  config,
  lib,
  ...
}:
let
  # Explicit membership keeps 343-guilty-spark and other hosts out of the hive.
  hosts = lib.getAttrs [
    "001-shamed-instrument"
    "007-contrite-witness"
    "049-abject-testament"
    "2401-penitent-tangent"
    "16807-abashed-eulogy"
    "117649-despondent-pyre"
  ] config.den.hosts.x86_64-linux;
in
{
  flake.apps.x86_64-linux.colmena = inputs.colmena.apps.x86_64-linux.colmena;

  flake.colmenaHive = inputs.colmena.lib.makeHive (
    {
      meta = {
        # legacyPackages adds a library overlay that nixosSystem does not use for pkgs.
        nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
        nodeNixpkgs = lib.mapAttrs (_: host: import host.nixpkgs { system = host.system; }) hosts;
        # Match nixosSystem's flake-aware library and version metadata.
        nodeSpecialArgs = lib.mapAttrs (_: host: { lib = host.nixpkgs.lib; } // host.specialArgs) hosts;
      };

      defaults.deployment = {
        buildOnTarget = false;
        targetUser = "root";
        tags = [ "m75q" ];
      };
    }
    // lib.mapAttrs (_: host: {
      imports = [ host.mainModule ];
      nixpkgs.flake.source = host.nixpkgs.outPath;
      # Tailscale MagicDNS names also work when the LAN is unreachable.
      deployment.targetHost = host.hostName;
    }) hosts
  );
}
