---
name: den
description: Explain, implement, migrate, and debug Den Nix configurations using entities, schemas, aspects, class modules, policies, batteries, and quirks. Use for Den-specific work or an explicitly requested Den adoption. Ordinary NixOS edits do not imply migration.
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

Audited 2026-09-29 against upstream main at
[`7594405b45e0ce2d5a418fe104a26e17f6b1dd8f`](https://github.com/denful/den/tree/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f).
The latest release at audit time is
[`v0.19.0`](https://github.com/denful/den/releases/tag/v0.19.0).
This repository still pins `d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d`.
Read the [version differences](references/sources.md) before applying newer APIs.
Do not update a consumer's input as part of ordinary Den work.

The unversioned website follows main. The documented release aliases are not all available.
At audit time, `/latest/` returns HTTP 404. Archives for `v0.17.0` through `v0.19.0` load.
Use the [archive status table](references/official-documentation.md#releases-and-archived-documentation) and commit-specific source for the consumer's revision.
[Versioning](https://den.denful.dev/releases/).

For conflicting examples, inspect documentation, implementation, and regression
tests at that revision. [Sources and known discrepancies](references/sources.md)
records source conflicts and evaluation evidence.
The [complete documentation index](references/official-documentation.md) links
every official documentation page and supporting Markdown file at the audited revision.

## Choose the right layer

| Layer | Put here |
| --- | --- |
| `den.hosts`, host `users`, `den.homes` | Instances and metadata: what machines and environments exist |
| `den.schema.<kind>` | Shared entity options, defaults, and activation by kind |
| `den.aspects.<feature>` | Behavior composed with `includes` and named sub-aspects |
| Aspect `nixos`, `darwin`, `homeManager`, etc. | Ordinary modules for the target evaluation class |
| `den.policies` | Entity relationships, context enrichment, and delivery effects activated through `includes` |
| `den.quirks` and policy pipes | Structured producer/consumer data within or across scopes |
| `den.batteries` | Built-in reusable aspects and integration helpers |

An entity kind, such as `host` or `user`, selects context during resolution.
A class, such as `nixos` or `homeManager`, selects a module evaluation domain.
A scope is one entity's resolution context. Keep these concepts distinct.
Feature composition does not require a particular directory
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
- For packages, flake-parts output routing, or typed aspect settings, read
  [Outputs and settings](references/outputs-and-settings.md).
- For all tutorials, batteries, case studies, project guides, and release notes,
  use the [official documentation index](references/official-documentation.md).

## Apply these distinctions when editing

1. Define reusable behavior once and include it at the intended entity scope.
   Defining a named aspect or registering a custom policy alone does not apply it.
2. Keep `includes` for aspect/policy composition and class-level `imports` for
   existing NixOS/Home Manager modules. The outer Den module is a different
   evaluation layer from either class module.
3. An entity's `.aspect` is an aspect value, not a string name.
   Use `host.aspect` / `user.aspect` directly when an API expects an aspect.
4. Context binding and output destination are separate. A host-level aspect
   requiring `user` can fan out over descendant users, but its output is still
   emitted at the host scope. Route Home Manager content to user scopes explicitly.
5. Ask for `pkgs`, `config`, and other class module arguments inside class modules.
   Capture `inputs` and `den` from the outer module, or use a documented scope battery. Do not assume Den context is globally installed in `specialArgs`.
6. Use `den.default` only for behavior intended across entity kinds, including hosts, users, and homes.
   Preserve per-host state versions and privileges during migration.
7. Use explicit host providers for OS changes from user aspects.
   Upstream tracks automatic user-to-host OS delivery as a bug.
   Do not assume that a planned `user-aspects` battery exists.

Sources: [schema reference](https://den.denful.dev/reference/schema/),
[parametric binding rule](https://den.denful.dev/explanation/parametric/),
[class modules](https://den.denful.dev/explanation/class-modules/),
[aspect configuration](https://den.denful.dev/guides/configure-aspects/),
[class destinations](https://den.denful.dev/explanation/where-config-lands/).

## Finish with evidence

Evaluate the affected output values and the repository's required checks. Report
what was actually verified and distinguish evaluation from a system build. Follow
the consuming repository's validation and activation rules. Cite the relevant
original documentation when explaining
Den behavior, and identify revision-specific implementation evidence where the
documentation differs.
