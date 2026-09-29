# Outputs and settings

Use this reference for flake outputs and typed per-aspect settings.
The examples in upstream guides depend on the revision recorded in [sources.md](sources.md).
Read the full linked guide before adding either pattern to a consumer.

## Flake outputs

Den creates host and home outputs through each entity's `instantiate` and `intoAttr` values.
Other outputs need both a declared output option and an aspect reached by the relevant scope.
Registering an aspect alone does not export its content.

| Content | Destination | Inclusion scope |
| --- | --- | --- |
| `packages`, `apps`, `checks`, `devShells`, `legacyPackages` | Corresponding `flake.<output>.<system>` | `den.schema.flake-system.includes`, or its reached descendants |
| `flake` | Top-level `flake.*` | Root or descendant scopes |
| Custom flake-parts class | A `perSystem` module path | An explicitly resolved `flake-parts` scope |

Without flake-parts, import the required `inputs.den.flakeOutputs.<output>` module.
With flake-parts, its declarations already enable the direct output routes.
Use `den.schema.flake-system.includes` for packages that must exist without hosts.
The root `den.schema.flake.includes` is above those per-system collection scopes.
There is no built-in `den.schema.flake-packages` kind.
A host with `intoAttr = [ ]` does not contribute through the default output traversal.

The consumer pin and `v0.19.0` contain a broken `flakeOutputs.all` module with `includes` instead of `imports`.
Import the individual output modules on those versions.
Upstream main fixes `all` in commit
[`6cceca4`](https://github.com/denful/den/commit/6cceca4).
Do not confuse this outer-module bug with aspect `includes`.

The default output evaluator uses `inputs.nixpkgs.legacyPackages.<system>`.
It does not inherit a host's overlays or package permissions.
Capture inputs in the outer module when a different package set is required.
Keep the host builder, Home Manager package set, and output package set distinct.

For flake-parts `perSystem` routing, include `system-to-flake-parts` at `flake-system` scope.
Include the relevant route, such as `packages-to-flake-parts`, at `flake-parts` scope.
Exclude the matching direct route, such as `packages-to-flake`, to avoid duplicate delivery.
Hosts are not descendants of `flake-parts` by default.
If host aspects must supply these outputs, add the required traversal explicitly.

Per-system output classes merge nested attribute sets and reject conflicting values.
The generic `flake` class merges only one level of output attributes.
Separate contributions to `flake.deploy.nodes.<host>` can silently replace one another.
For deeper structures, assemble the final value in one place or use an appropriate declared output module.

Read [Flake outputs from aspects](https://den.denful.dev/guides/flake-outputs/),
[output reference](https://den.denful.dev/reference/output/), and the
[flake-parts modules template](https://den.denful.dev/tutorials/flake-parts-modules/).

## Typed aspect settings

The upstream settings guide describes a user-defined pattern, not a built-in battery.
It reserves `settings`, reads declarations from static aspects, and builds a typed entity option.
The consumer must supply the generator and schema wiring.

For a small number of shared fields, typed `den.schema.host` options remain sufficient.
If the task needs aspect-local declarations, read the full generator before adapting it.
Make sure that it skips structural keys, class keys, and quirk keys.
The generator depends on internal key classification and needs revision-specific evaluation.

Declare an aspect's settings in one place.
Reserved keys do not merge independent definitions across files.
Use the settings module's `imports` when declarations need several files.
A wholly parametric aspect hides its settings from the static tree walk.
Keep declarations on the static aspect and put entity-dependent behavior inside class modules.

Settings are entity inputs. Quirks publish data for other aspects or scopes.
Do not replace one mechanism with the other based only on similar attribute shapes.
The proposed gen-based redesign is future work, not an available settings API.

Read [Aspect settings](https://den.denful.dev/guides/aspect-settings/),
[reserved keys](https://den.denful.dev/reference/aspects/#reserved-keys), and
[Den on gen](https://den.denful.dev/future/).
