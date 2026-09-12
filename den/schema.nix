{
  inputs,
  lib,
  den,
  ...
}:
{
  # The blanket strict module also rejects valid nixos aspect content at our
  # pinned Den revision. Restrict entity metadata while preserving class modules.
  den.schema.user = den.lib.strict;
  den.schema.home = den.lib.strict;

  den.schema.host =
    { config, ... }:
    {
      imports = [ den.lib.strict ];

      options = {
        nixpkgs = lib.mkOption {
          type = lib.types.raw;
          default = inputs.nixpkgs;
          description = "Nixpkgs input used to instantiate this NixOS host.";
        };
        specialArgs = lib.mkOption {
          type = lib.types.attrsOf lib.types.raw;
          default = { };
          description = "Arguments required by host-local NixOS modules; shared aspects capture their inputs directly.";
        };
      };

      config.instantiate = lib.mkDefault (
        args:
        config.nixpkgs.lib.nixosSystem (
          args
          // {
            system = config.system;
            specialArgs = (args.specialArgs or { }) // config.specialArgs;
          }
        )
      );
    };
}
