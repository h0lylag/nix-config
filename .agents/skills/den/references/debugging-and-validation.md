# Debugging and validation

## Diagnose from the output back to the aspect

Start with the expected output and setting. Use `nix repl`, `:lf .`, and inspect
`nixosConfigurations.<host>.config`, or use a targeted `nix eval`. A successful
evaluation of an unrelated attribute does not prove an aspect applied.

| Symptom | Inspect |
| --- | --- |
| Unknown `den.*` option | Is `inputs.den.flakeModule` in the outer Den evaluator, rather than the OS evaluator? |
| Defined feature has no effect | Is it included on the intended entity, and is its class evaluated there? |
| Custom policy never runs | Registry alone is insufficient; check active `includes`, predicates, required context, and exclusions |
| User parameter produces no result | Is the user in scope or a schema descendant? Root/sibling contexts do not imply fan-out |
| Host feature's Home Manager settings disappear | Route to user scope or opt into `host-aspects`; host fan-out does not deliver HM automatically |
| `pkgs`/`config` missing or wrong | Check the outer Den, aspect submodule, and class module boundaries |
| Duplicate argument/collision | Inspect class `specialArgs` and `_module.args` versus Den's injected context |
| List entries repeated or one user missing | Inspect scope, aspect identity, declared entity arguments, and duplicate legacy imports |
| Standalone home lacks host fields | A synthetic hostname/user identity is not a complete declared OS host/user |
| Output absent or colliding | Inspect entity `class`, `instantiate`, `intoAttr`, full home key, and traversal |
| Module file absent | Check explicit imports or the actual import-tree filters, including underscore paths and Git visibility |

Sources: [debugging guide](https://den.denful.dev/guides/debug/),
[class modules](https://den.denful.dev/explanation/class-modules/),
[parametric rule](https://den.denful.dev/explanation/parametric/),
[output reference](https://den.denful.dev/reference/output/).

## Inspect the resolution without reinventing it

Temporarily expose `flake.den = den` from an outer module if internal inspection
is needed. With a hand-written outputs function, also ensure it returns that
temporary output. In the REPL, inspect an entity's `.mainModule`, `.aspect`, or
selected metadata. Remove temporary debug outputs afterward.

Prefer the existing host's complete configuration for OS checks; evaluating a
bare `mainModule` with generic `lib.evalModules` does not supply all NixOS options
or the original builder's arguments. `den.lib.aspects.resolve` is a lower-level
debug/library API, not a replacement for the entity pipeline in routine host
configuration. Upstream `just repl` loads Den's own CI context, rather than the consumer's configuration.
[Debug configurations](https://den.denful.dev/guides/debug/).

For graph diagnosis, Den captures traces through `den.lib.capture`; rendering
uses the separate `den-diagram` library. The documented flow is
`captureWithPathsWith` with classes, a `resolveEntity` root and context, then
`diagram.context` and `diagram.toMermaid`. Check both package revisions before
copying a signature. A static aspect catalog graph does not prove runtime
inclusion, policy activation, or class delivery.
[Capture and rendering reference](https://den.denful.dev/reference/diag/).

## Structural conditions and recursion

`host.hasAspect ref` inspects structural membership, not whether a NixOS option
is enabled. Class module bodies may use it after the tree resolves. Do not use
the result in an ordinary `if` that constructs the same tree's `includes` list;
that introduces a dependency cycle.

For conditional tree composition use the documented `policy.when` over an
inline aspect (compiled as a guarded aspect), or subtree constraints through
`meta.handleWith`. Read the constraint API before constructing exclude/replace
records; do not confuse structural constraints with `lib.mkIf` over OS options.
[Structural introspection](https://den.denful.dev/explanation/structural-introspection/),
[aspect metadata reference](https://den.denful.dev/reference/aspects/).

## Migrating older Den APIs

Detect the locked version before replacing an old API. For the research revision:

| Older API | Current direction |
| --- | --- |
| `den.ctx.<kind>` | Separate behavior into aspects and activate with `den.schema.<kind>.includes` |
| `den.ctx.*.into` | Explicit traversal policies, registered and activated |
| `meta.adapter` | Removed; use the current class routing model |
| `den.lib.ctxApply` | Removed without shim; use entity/aspect activation |
| `den.lib.parametric`, `take`, `canTake` | Bare parametric aspects and class context injection |
| `den.lib.perHost`, `perUser`, `perHome` | Deprecated shims; use the current binding rule deliberately |

The `den.ctx` compatibility shim does not make every historical transition
equivalent. Do not mechanically translate string-valued `.aspect` examples or
recreate a built-in host-to-user traversal already activated by the framework.
[Migration guide](https://den.denful.dev/guides/migrate-ctx/),
[deprecated library reference](https://den.denful.dev/reference/lib-deprecated/).

## Validation

Follow the consuming repository's checks. For a NixOS flake, common evaluation
checks are:

```sh
nixfmt --check path/to/changed.nix
nix flake check --no-build --no-write-lock-file
```

Inspect representative affected values, including multiple users when changing
dispatch and both producer/consumer hosts when changing fleet data. When a real
system build is warranted, use:

```sh
nix build .#nixosConfigurations.demo.config.system.build.toplevel --no-link
```

Substitute the affected host. Keep input changes intentional and preserve the
existing state versions. During a structural migration, compare the before/after
`system.build.toplevel.drvPath` values with unchanged package inputs: equal paths
show identical build recipes, while differences need investigation. Neither
evaluation nor derivation equality proves runtime behavior. Respect the project's
authorization rules before activation. For skill/documentation edits, check links
and examples separately from evaluating the consumer's existing flake.
