# Integration and migration

Match the consuming flake's Den revision; see [sources.md](sources.md).

## Bootstrapping the framework

Declare an `inputs.den` flake input at the chosen release or revision, then import
`inputs.den.flakeModule` into an **outer Den module evaluation**. It is not a
NixOS module to put directly into `nixosSystem.modules`. The evaluator must supply
nixpkgs `lib` and the `inputs` argument. Den supplies its own `den` module argument.
Neither flake-parts nor import-tree is required.
[From flake to Den](https://den.denful.dev/guides/from-flake-to-den/),
[minimal template](https://den.denful.dev/tutorials/minimal/).

This original outer module, assumed to be `den/default.nix`, declares a small
example host and composes one feature:

```nix
{ inputs, den, ... }:
{
  imports = [ inputs.den.flakeModule ];
  den.hosts.x86_64-linux.demo = { };
  den.aspects.demo.includes = [ den.aspects.host-label ];
  den.aspects.host-label = { host }: {
    nixos.environment.etc."den-host".text = host.hostName;
  };
}
```

An evaluator for it is:

```nix
inputs:
(inputs.nixpkgs.lib.evalModules {
  specialArgs = { inherit inputs; };
  modules = [ ./den/default.nix ];
}).config
```

The evaluator shown returns `.den` (the Den configuration) and `.flake` (generated
outputs). If that result is named `denConfig`, return `denConfig.flake` from a
Den-only flake's `outputs`; equivalently, use `(lib.evalModules { ...; }).config.flake`.
This example
illustrates wiring, not a bootable machine: retain or provide the real hardware,
filesystems, bootloader, accounts, and existing `system.stateVersion`.

With flake-parts, import Den's module into `mkFlake`'s module graph. Den uses
flake-parts' `flake` output option when that input exists. If independently
evaluating Den with `lib.evalModules` while `inputs.flake-parts` exists, import
`inputs.den.flakeOutputs.flake` to provide the otherwise missing output option.
[Output reference](https://den.denful.dev/reference/output/),
[flake-parts migration detail](https://den.denful.dev/guides/from-flake-to-den/#migrating-with-flake-parts).

## Incremental adoption

When migration is requested, a small first step is to evaluate Den separately
and append `denConfig.den.hosts.x86_64-linux.<host>.mainModule` to the existing
host's `nixosSystem.modules`. Preserve the current builder, `specialArgs`, and
module list. Use the host's real name in the Den declaration. This keeps the
existing output construction while adding an aspect incrementally.
[Original incremental adoption guide](https://den.denful.dev/guides/from-flake-to-den/).

Alternatively, a host aspect can import existing OS modules under
`den.aspects.<host>.nixos.imports`. Avoid retaining the same settings through two
competing migration paths. Preserve the project's hardware/storage layout,
module interfaces, and nested-system boundaries. Den adoption does not require
converting containers and VMs into top-level Den hosts.

When Den eventually owns output instantiation, set `host.instantiate` to preserve
the builder and arguments. This original outer module fragment illustrates the
shape for a host using an alternate nixpkgs input; retain every existing
`specialArgs` value when adapting it:

```nix
{ inputs, ... }:
{
  den.hosts.x86_64-linux.demo.instantiate = args:
    inputs.nixpkgs-unstable.lib.nixosSystem (args // {
      specialArgs = (args.specialArgs or { }) // {
        inherit (inputs) nixpkgs-unstable;
      };
    });
}
```

Den passes modules including `host.mainModule` and a default host platform to
this builder. Changing the builder alone does not recreate all previous module
imports or argument wiring. [Instantiation reference](https://den.denful.dev/reference/output/).

## Import-tree migration adapter

The optional `den.batteries.import-tree.provides.host root` looks under
`root/<host.name>/_<class>/`, for example `legacy/host-a/_nixos/`. The analogous
`.user` and `.home` adapters select user/home names. Activate them on the
corresponding `den.schema.<kind>.includes`; `inputs.import-tree` is required.

This is different from using `inputs.import-tree` to discover outer Den modules.
An existing `hosts/<name>/default.nix` layout is not automatically compatible
with the class-directory adapter. Explicit class-level imports may be simpler. Avoid recursively importing both a legacy entry point and
all of the modules it already imports.
[Migration guide](https://den.denful.dev/guides/migrate/),
[battery implementation](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/modules/aspects/batteries/import-tree.nix).

## Users, Home Manager, and batteries

Declaring a user entity is distinct from setting up the intended OS account.
The built-in `user` class routes settings to `users.users.<userName>` on the OS.
Choose the appropriate account settings directly or include `define-user` for a
normal user and conventional home directory. Do not apply it indiscriminately to
service accounts. `primary-user` grants `wheel` and `networkmanager` groups on
NixOS; use it only for intended administrators.
[Home environments](https://den.denful.dev/guides/home-manager/),
[battery reference](https://den.denful.dev/reference/batteries/).

For host-managed Home Manager, provide `inputs.home-manager` (or override the
host's `home-manager.module`), and opt users into `classes = [ "homeManager" ]`.
The host's `home-manager.enable` defaults from user class membership. Preserve
any explicit override and the integration's supported OS classes. The built-in
integration detects eligible users, imports the OS integration,
and routes user-scope `homeManager` content to `home-manager.users.<userName>`.
Put shared user behavior in user aspects or `den.schema.user.includes`.
An aspect's `homeManager` key alone does not opt any user into Home Manager.

Standalone `den.homes.<system>.alice` generates `homeConfigurations.alice`;
`den.homes.<system>."alice@demo"` generates the full `"alice@demo"` output key.
Use the user aspect `den.aspects.alice`. A declared matching host can supply
`osConfig`; an external hostname does not imply an evaluated host configuration.
At the research revision, standalone homes also bind an identity-only user when
no declared host user exists. Write standalone behavior against `home` data or
check which fields a synthesized user/host actually has.
[Homes guide](https://den.denful.dev/guides/home-manager/),
[verified home implementation](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/nix/lib/entities/home.nix).

Preserve `home.stateVersion` and `system.stateVersion`; an upstream tutorial's
values are examples. Home Manager, hjem, and maid are separate classes with
separate module inputs and supported platforms. Add only the integration the
user wants. [Home integration requirements](https://den.denful.dev/guides/home-manager/).

Useful batteries to investigate for a concrete task:

| Battery | Purpose and decision |
| --- | --- |
| `hostname` | Apply entity hostname metadata to the OS |
| `define-user` | Conventional normal-account and home identity settings |
| `primary-user` | Administrator/platform primary-user settings |
| `user-shell` | Configure an intended login shell; check its argument API |
| `os-class`, `os-user` | Built-in cross-OS class routing, including the lightweight `user` class |
| `host-aspects` | User opts into projecting host aspect content for the user's classes |
| `forward` | Forward a class into another class/path |
| `unfree`, `insecure` | Scoped package policy; preserve the user's intended allowlist |
| `inputs'`, `self'` | System-indexed flake-parts conveniences when that integration is present |
| `flake-scope` | Explicitly make outer scope values available to pipeline aspects |

Read the [battery reference](https://den.denful.dev/reference/batteries/) and the
linked battery-specific guide before selecting parameters. A battery's presence
in the registry does not mean it must be manually enabled; some class/integration
policies are already wired by the framework.

For verification and old API migrations, continue with
[Debugging and validation](debugging-and-validation.md).
