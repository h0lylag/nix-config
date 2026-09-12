---
name: den
description: Explain, implement, migrate, and debug Den Nix configurations using entities, schemas, aspects, class modules, policies, batteries, and quirks. Use for Den-specific work or an explicitly requested Den adoption; ordinary NixOS edits do not imply migration.
---

# Den

Use Den to compose configuration by feature across Nix module classes while
keeping entity declarations and routing explicit. This skill is a researched
guide, not an instruction to adopt Den whenever editing Nix.

## Establish the version and evaluation boundary

Read the repository's `AGENTS.md`, `flake.nix`, `flake.lock`, and relevant imports.
Find the actual Den input and locked revision before selecting APIs. Also identify
the evaluator (`lib.evalModules`, flake-parts, or an existing OS builder), package
inputs, class integrations, and how files enter the module graph.

Research baseline: **2026-09-12**, upstream `denful/den` main at
[`d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d`](https://github.com/denful/den/tree/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d).
The unversioned documentation tracks main; `/latest/` tracks the moving release
tag, and versioned documentation is available for releases. Match the consumer's
pin, rather than assuming these notes describe every release.
[Original versioning documentation](https://den.denful.dev/releases/).

For conflicting examples, inspect documentation, implementation, and regression
tests at that revision. [Sources and known discrepancies](references/sources.md)
records the important conflicts found during this research.

## Choose the right layer

| Layer | Put here |
| --- | --- |
| `den.hosts`, host `users`, `den.homes` | Instances and metadata: what machines and environments exist |
| `den.schema.<kind>` | Shared entity options/defaults; kind-wide aspect or policy activation |
| `den.aspects.<feature>` | Behavior composed with `includes` and named sub-aspects |
| Aspect `nixos`, `darwin`, `homeManager`, etc. | Ordinary modules for the target evaluation class |
| `den.policies` | Entity relationships, context enrichment, and delivery effects; activate through `includes` |
| `den.quirks` and policy pipes | Structured producer/consumer data within or across scopes |
| `den.batteries` | Built-in reusable aspects and integration helpers |

An **entity kind** such as `host` or `user` selects pipeline context; a **class**
such as `nixos` or `homeManager` selects a module evaluation domain. Keep these
distinct. Feature-oriented composition does not require a particular directory
layout. [Core principles](https://den.denful.dev/explanation/core-principles/),
[entities](https://den.denful.dev/explanation/entities/).

## Work from the relevant reference

- For declarations, file structure, includes/provides, dispatch, and class module
  arguments, read [Structure and aspects](references/structure-and-aspects.md).
- For flake wiring, existing NixOS modules, mixed nixpkgs inputs, users, Home
  Manager, batteries, and validation, read
  [Integration and migration](references/integration-and-migration.md).
- For cross-entity configuration, custom classes, policies, quirks, and fleet
  data, read [Policies and data flow](references/policies-and-data-flow.md).
- For missing configuration, recursion, tracing, older APIs, and verification,
  read [Debugging and validation](references/debugging-and-validation.md).

## Apply these distinctions when editing

1. Define reusable behavior once and include it at the intended entity scope.
   Defining a named aspect or registering a custom policy alone does not apply it.
2. Keep `includes` for aspect/policy composition and class-level `imports` for
   existing NixOS/Home Manager modules. The outer Den module is a different
   evaluation layer from either class module.
3. At this revision, entity `.aspect` is the **aspect value**, not a string name.
   Use `host.aspect` / `user.aspect` directly when an API expects an aspect.
4. Context binding and output destination are separate. A host-level aspect
   requiring `user` can fan out over descendant users, but its output is still
   emitted at the host scope. Route Home Manager content to user scopes explicitly.
5. Ask for `pkgs`, `config`, and other class module arguments inside class modules;
   use an outer Den module closure for `inputs`/`den`, or a documented scope battery
   when necessary. Do not assume Den context is globally installed in `specialArgs`.
6. Use `den.default` only for behavior intended across hosts, users, and homes.
   Preserve per-host state versions and privileges during migration.

Sources: [schema reference](https://den.denful.dev/reference/schema/),
[parametric binding rule](https://den.denful.dev/explanation/parametric/),
[class modules](https://den.denful.dev/explanation/class-modules/),
[aspect configuration](https://den.denful.dev/guides/configure-aspects/).

## Finish with evidence

Evaluate the affected output values and the repository's required checks. Report
what was actually verified and distinguish evaluation from a system build. Follow
the consuming repository's validation and activation rules. Cite the relevant
original documentation when explaining
Den behavior, and identify revision-specific implementation evidence where the
documentation differs.
