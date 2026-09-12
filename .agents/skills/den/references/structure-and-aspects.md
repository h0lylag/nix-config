# Structure and aspects

Version scope and source discrepancies are recorded in [sources.md](sources.md).

## File structure and module boundaries

Den supplies a domain-independent library and an optional configuration framework.
The framework's `inputs.den.flakeModule` can run under `nixpkgs.lib.evalModules`
without flake-parts. `import-tree` and `flake-file` are optional tooling choices,
not requirements of the Den model.
[Library versus framework](https://den.denful.dev/explanation/library-vs-framework/),
[minimal template](https://den.denful.dev/tutorials/minimal/).

A possible layout for an existing repository is:

```text
flake.nix                    inputs and evaluator/output wiring
den/                         outer Den modules, explicitly imported
  default.nix                imports inputs.den.flakeModule and local Den modules
  inventory.nix              hosts, users, homes, schema
  aspects/                   feature definitions and composition
  policies.nix               custom relationships/data flow, if needed
hosts/<name>/                existing host-local NixOS and hardware modules
profiles/, features/         existing reusable NixOS modules
```

This is an example arrangement, not a mandatory Den layout. Upstream templates
commonly call their outer module directory `modules/`. In an existing project,
that name may already refer to plain NixOS modules: inspect the module boundaries
before recursively importing it at the Den level. Explicit imports are sufficient.
[Incremental adoption](https://den.denful.dev/guides/from-flake-to-den/).

There are three distinct contexts in this original example:

```nix
{ den, inputs, ... }: # Outer Den configuration module.
{
  den.aspects.service = { host }: { # Aspect context supplied by Den.
    nixos = { pkgs, ... }: { # NixOS module arguments.
      environment.etc."den-host".text = host.hostName;
      environment.systemPackages = [ pkgs.hello ];
    };
  };
}
```

An outer module's `config` refers to that Den configuration; an aspect submodule's
`config` refers to that aspect; `config` inside `nixos` refers to NixOS. Preserve
the lexical boundary rather than treating them as interchangeable.
[Configure aspects](https://den.denful.dev/guides/configure-aspects/).

## Entity declarations and schema

The canonical host path is `den.hosts.<system>.<name>`; users live under its
`users.<name>`. `den.homes.<system>.<name>` produces standalone homes. A flat host
or home declaration with `system` inside the value is also supported at the
research revision. Prefer the existing repository style.

`name` identifies a configuration, `hostName` its network hostname, and `userName`
the OS account. Host class defaults to `nixos` or `darwin` based on platform;
home class defaults to `homeManager`; a user's `classes` defaults to `[ "user" ]`.
The entity's `.aspect` defaults to the corresponding `den.aspects.<name>` value.

Schema modules configure metadata, not NixOS options. For example:

```nix
{ lib, ... }:
{
  den.schema.host = {
    options.site = lib.mkOption {
      type = lib.types.str;
      default = "home";
    };
  };
  den.hosts.x86_64-linux.demo.site = "lab";
}
```

Use `den.schema.conf` for shared host/user/home options and
`den.schema.<kind>.includes` to activate aspects or policies for a kind. Freeform
metadata is allowed by default; typed options are useful for common fields.
`inputs.den.flakeModules.strict` opts into declared attributes for supported
schema kinds. Do not infer that metadata such as `host.site` is itself an OS
setting. [Entities](https://den.denful.dev/explanation/entities/),
[schema reference](https://den.denful.dev/reference/schema/).

## Aspect composition

An aspect contains class modules, an `includes` graph, and named child aspects
under `provides` (also accessible through direct nesting). Use real aspect
references in `includes`. General named children group reusable behavior; they
are not all automatically included just because their parent is included.
Host/user-targeted providers have special routing semantics, described in
[Policies and data flow](policies-and-data-flow.md).

```nix
{ den, ... }:
{
  den.aspects.tools = {
    nixos = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.git ];
    };
    provides.editor.homeManager.programs.helix.enable = true;
  };
  den.aspects.demo.includes = [ den.aspects.tools ];
  den.aspects.alice.includes = [ den.aspects.tools.editor ];
}
```

Here the host receives Git and the user receives the editor when their entities
are declared and Home Manager is wired. Including the host aspect does not by
itself select every child provider or deliver its home configuration to users.

Use `nixos.imports = [ ./existing.nix ];` for an existing NixOS module. Putting
that plain module in an aspect's `includes`, or putting OS options directly at
the outer Den level, crosses the wrong boundary. Prefer named aspects for useful
trace identities. Keep the include graph acyclic; avoid assuming deduplication
means arbitrary function outputs will merge exactly once across all scopes.
[Aspects](https://den.denful.dev/explanation/aspects/),
[configure aspects](https://den.denful.dev/guides/configure-aspects/).

## Parametric binding and emission

At the research revision, an aspect requiring an entity argument follows this
rule relative to the scope where it is included:

| Requested entity | Behavior |
| --- | --- |
| Already in context | Bind it at the current scope |
| Descendant in the entity schema | Fan out over matching descendants, emitting at the original scope |
| Neither | Contribute nothing, silently |

Arguments with Nix defaults, such as `{ user ? null }:`, are optional; they do
not impose the same required-argument gate. Use a required argument when its
presence is intended to control application.
[Binding implementation](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/nix/lib/aspects/fx/handlers/bind.nix).

Thus a host-level `{ user }: { nixos = ...; }` can produce per-user OS settings.
Its `homeManager` content does **not** thereby become user Home Manager content.
Use user-scope inclusion, `provides.to-users`, an explicit delivery policy, or
the opt-in `host-aspects` battery. Entity arguments at the flake root are not a
shortcut for iterating over all hosts. Static class modules naming descendant
entity kinds are promoted to equivalent fan-out.
[Parametric aspects](https://den.denful.dev/explanation/parametric/),
[home scope warning](https://den.denful.dev/guides/home-manager/#host-scope-parametric-aspects-no-longer-deliver-homemanager-content-to-users).

The two-layer form above is useful when entity data determines the entire aspect.
Flat class modules are convenient when only one class needs it:

```nix
{
  den.aspects.host-label.nixos = { host, ... }: {
    environment.etc."den-host".text = host.hostName;
  };
}
```

Den pre-applies available context arguments and leaves module-system arguments
for Nix. Include `...` on module functions that reach the class evaluator. A
function whose arguments are entirely provided by Den may instead be fully
applied by Den. Same-name arguments from Den and class `specialArgs`/`_module.args`
default to a collision error; investigate the competing values before selecting
`den-wins` or `class-wins`. Missing, unreachable entity arguments can skip a
module; do not rely on a warning being forced during lazy evaluation.
[Class modules](https://den.denful.dev/explanation/class-modules/),
[collision settings](https://den.denful.dev/reference/aspects/).

## Optional naming conveniences

`inputs.den.namespace "team" false` creates a local `den.ful.team` namespace
and a `team` module argument. `true` exports `flake.denful.team`; a list of input
flakes imports the corresponding namespace, optionally including `true` to
re-export it. Ordinary `den.aspects` is enough for a local configuration.
[Namespaces](https://den.denful.dev/guides/namespaces/).

Angle-bracket lookups require `_module.args.__findFile = den.lib.__findFile`
and lexical `__findFile` in each using module's argument pattern. With that
setup, `<den/hostname>` refers to a battery and `<tools/editor>` to an aspect
child. Otherwise angle brackets retain ordinary Nix lookup semantics. Prefer
explicit attribute references when the project has not enabled this syntax.
[Angle brackets](https://den.denful.dev/guides/angle-brackets/).
