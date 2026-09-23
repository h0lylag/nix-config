# Package overlays

`default.nix` is the explicit catalogue. Den aspects select its entries; adding
a file here does not apply it to a machine. Its `sources` entry exposes the
separately pinned `pkgs.stable` and `pkgs.unstable` package sets without applying
the host's overlays to either set.

- `local.nix` discovers every top-level `pkgs/<name>/package.nix` under
  `pkgs.local`, including recipes for dormant services. It keeps explicit
  entries only for package-set and argument exceptions. The recipe, source
  pin, and package-specific patches stay together in `pkgs/<name>/`.
  Multi-package recipes such as `dayz-tools` retain their nested attributes.
- `replacements/tailscale.nix` selects the same pinned package for the Tailscale
  service and packages such as Trayscale that depend on `pkgs.tailscale`.
- `fixes/` holds scoped workarounds. Recheck them when updating their upstream
  packages and remove them once the upstream issue is fixed.

Keep service-specific package choices and argument overrides in their service
modules. Nested NixOS containers have their own package evaluations and import
the shared overlays through `den.aspects.container-base.nixos`.
