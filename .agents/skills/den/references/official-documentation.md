# Official documentation index

Audited 2026-09-29 against Den main `7594405b45e0ce2d5a418fe104a26e17f6b1dd8f`.
This index covers all 74 documentation pages and all 22 other tracked Markdown files in the official Den repository.
It also links all 19 published release notes and the sidebar entries for individual batteries.
The scope is Den itself. External projects and community configurations are not additional Den documentation.

Website links follow main. Each source link fixes the content to the audited commit.
“Added” means that the page is absent from this repository's Den pin, not that every described API is new.
Use [sources.md](sources.md) for revision differences and unresolved documentation conflicts.
Load the pages needed for the task rather than loading this entire catalog by default.

## Start and project

These pages explain the project, its workflow, and version selection.
The future page describes both shipped schema dependencies and an unshipped redesign.
Use the release section below when working on older pins.

| Official page | Audited source | At consumer pin |
| --- | --- | --- |
| [Community](https://den.denful.dev/community/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/community.mdx) | Present |
| [Contributing](https://den.denful.dev/contributing/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/contributing.mdx) | Present |
| [Future: den on gen](https://den.denful.dev/future/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/future.mdx) | Added |
| [Context-aware Aspect-oriented Nix](https://den.denful.dev/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/index.mdx) | Present |
| [Maintainers Guide](https://den.denful.dev/maintainers/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/maintainers.mdx) | Present |
| [Why Den?](https://den.denful.dev/motivation/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/motivation.mdx) | Present |
| [Documentation Overview](https://den.denful.dev/overview/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/overview.mdx) | Present |
| [Den Releases and Versioning](https://den.denful.dev/releases/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/releases.mdx) | Present |

## Explanations

Use these pages to choose a mechanism and understand its scope. Start with class destinations when configuration disappears. Consult pipeline internals only when ordinary output inspection is insufficient.

| Official page | Audited source | At consumer pin |
| --- | --- | --- |
| [Aspects & Functors](https://den.denful.dev/explanation/aspects/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/aspects.mdx) | Present |
| [Choosing a Mechanism](https://den.denful.dev/explanation/choosing-a-mechanism/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/choosing-a-mechanism.mdx) | Added |
| [Class Modules](https://den.denful.dev/explanation/class-modules/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/class-modules.mdx) | Present |
| [Coming from...](https://den.denful.dev/explanation/coming-from/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/coming-from.mdx) | Present |
| [Resolution Pipeline](https://den.denful.dev/explanation/context-pipeline/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/context-pipeline.mdx) | Present |
| [den.ctx (Compatibility Shim)](https://den.denful.dev/explanation/context-system/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/context-system.mdx) | Present |
| [Core Principles](https://den.denful.dev/explanation/core-principles/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/core-principles.mdx) | Present |
| [Diagrams](https://den.denful.dev/explanation/diagrams/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/diagrams.mdx) | Present |
| [ABC on Den Effects](https://den.denful.dev/explanation/effects/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/effects.mdx) | Present |
| [Entities & Schema](https://den.denful.dev/explanation/entities/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/entities.mdx) | Present |
| [Fleets & Multi-Host](https://den.denful.dev/explanation/fleet/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/fleet.mdx) | Present |
| [Library vs Framework](https://den.denful.dev/explanation/library-vs-framework/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/library-vs-framework.mdx) | Present |
| [Parametric Aspects](https://den.denful.dev/explanation/parametric/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/parametric.mdx) | Present |
| [Policies](https://den.denful.dev/explanation/policies/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/policies.mdx) | Present |
| [Policy Activation Deep Dive](https://den.denful.dev/explanation/policy-activation/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/policy-activation.mdx) | Present |
| [Quirks & Pipes](https://den.denful.dev/explanation/quirks-and-pipes/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/quirks-and-pipes.mdx) | Present |
| [Scope Partitioning](https://den.denful.dev/explanation/scope-partitioning/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/scope-partitioning.mdx) | Present |
| [Structural Introspection & Constraints](https://den.denful.dev/explanation/structural-introspection/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/structural-introspection.mdx) | Present |
| [Where Does My Config Land?](https://den.denful.dev/explanation/where-config-lands/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/explanation/where-config-lands.mdx) | Added |

## Guides

Use these pages for concrete configuration work. Settings, case studies, and custom classes can require helper code from the page. Keep consumer-specific module boundaries and inputs intact.

| Official page | Audited source | At consumer pin |
| --- | --- | --- |
| [Case Study: Access Control & Environments](https://den.denful.dev/guides/acl-environments/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/acl-environments.mdx) | Added |
| [Angle Brackets Syntax](https://den.denful.dev/guides/angle-brackets/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/angle-brackets.mdx) | Present |
| [Aspect Settings](https://den.denful.dev/guides/aspect-settings/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/aspect-settings.mdx) | Added |
| [Use Batteries](https://den.denful.dev/guides/batteries/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/batteries.mdx) | Present |
| [Configure Aspects](https://den.denful.dev/guides/configure-aspects/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/configure-aspects.mdx) | Present |
| [Custom Class Examples](https://den.denful.dev/guides/custom-class-examples/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/custom-class-examples.mdx) | Added |
| [Custom Nix Classes](https://den.denful.dev/guides/custom-classes/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/custom-classes.mdx) | Present |
| [Debug Configurations](https://den.denful.dev/guides/debug/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/debug.md) | Present |
| [Declare Hosts & Users](https://den.denful.dev/guides/declare-hosts/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/declare-hosts.mdx) | Present |
| [Flake Outputs from Aspects](https://den.denful.dev/guides/flake-outputs/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/flake-outputs.mdx) | Added |
| [From Flake to Den](https://den.denful.dev/guides/from-flake-to-den/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/from-flake-to-den.mdx) | Present |
| [From Zero to Den](https://den.denful.dev/guides/from-zero-to-den/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/from-zero-to-den.mdx) | Present |
| [Home Environments](https://den.denful.dev/guides/home-manager/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/home-manager.mdx) | Present |
| [Migrating from den.ctx](https://den.denful.dev/guides/migrate-ctx/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/migrate-ctx.mdx) | Present |
| [Migrate to Den](https://den.denful.dev/guides/migrate/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/migrate.mdx) | Present |
| [Host<->User Mutual Providers](https://den.denful.dev/guides/mutual/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/mutual.mdx) | Present |
| [Share with Namespaces](https://den.denful.dev/guides/namespaces/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/namespaces.mdx) | Present |
| [nixpkgs: Overlays, Channels and Patches](https://den.denful.dev/guides/nixpkgs/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/nixpkgs.mdx) | Added |
| [Quirk Recipes](https://den.denful.dev/guides/quirk-recipes/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/quirk-recipes.mdx) | Added |
| [Cross-Scope Pipes](https://den.denful.dev/guides/quirks-cross-scope/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/quirks-cross-scope.mdx) | Added |
| [Quirks & Pipes](https://den.denful.dev/guides/quirks/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/quirks.mdx) | Present |
| [Standalone Home Manager](https://den.denful.dev/guides/standalone-home-manager/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/guides/standalone-home-manager.mdx) | Added |

## API references

Use these pages for names, types, signatures, and integration requirements. Follow implementation links when a guide and reference disagree. Match the source revision to the consumer.

| Official page | Audited source | At consumer pin |
| --- | --- | --- |
| [den.aspects](https://den.denful.dev/reference/aspects/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/aspects.mdx) | Present |
| [Batteries](https://den.denful.dev/reference/batteries/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/batteries.mdx) | Present |
| [den.lib.capture & den-diagram](https://den.denful.dev/reference/diag/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/diag.mdx) | Present |
| [Glossary](https://den.denful.dev/reference/glossary/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/glossary.mdx) | Present |
| [den.lib (deprecated)](https://den.denful.dev/reference/lib-deprecated/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/lib-deprecated.mdx) | Present |
| [den.lib](https://den.denful.dev/reference/lib/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/lib.mdx) | Present |
| [Output](https://den.denful.dev/reference/output/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/output.mdx) | Present |
| [den.policies](https://den.denful.dev/reference/policies/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/policies.mdx) | Present |
| [den.quirks](https://den.denful.dev/reference/quirks/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/quirks.mdx) | Present |
| [Schema](https://den.denful.dev/reference/schema/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/reference/schema.mdx) | Present |

## Tutorials and case studies

Use these pages with their corresponding template source. They demonstrate particular input sets and evaluators. Hardware, privileges, state versions, and activation commands are examples rather than migration defaults.

| Official page | Audited source | At consumer pin |
| --- | --- | --- |
| [Template: Bug Reproduction](https://den.denful.dev/tutorials/bogus/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/bogus.mdx) | Present |
| [Case Study: Visualising a Fleet with den-diagram](https://den.denful.dev/tutorials/case-study-diagrams/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/case-study-diagrams.mdx) | Added |
| [Case Study: Disks and Impermanence](https://den.denful.dev/tutorials/case-study-disks-impermanence/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/case-study-disks-impermanence.mdx) | Added |
| [Case Study: Kubernetes from a NixOS Fleet](https://den.denful.dev/tutorials/case-study-kubernetes/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/case-study-kubernetes.mdx) | Added |
| [Template: CI Tests](https://den.denful.dev/tutorials/ci/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/ci.mdx) | Present |
| [Template: Default](https://den.denful.dev/tutorials/default/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/default.mdx) | Present |
| [Template: Example](https://den.denful.dev/tutorials/example/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/example.mdx) | Present |
| [Template: Flake Parts Modules](https://den.denful.dev/tutorials/flake-parts-modules/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/flake-parts-modules.mdx) | Present |
| [Template: Fleet Demo](https://den.denful.dev/tutorials/fleet-demo/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/fleet-demo.mdx) | Present |
| [Template: MicroVM](https://den.denful.dev/tutorials/microvm/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/microvm.mdx) | Present |
| [Template: Minimal](https://den.denful.dev/tutorials/minimal/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/minimal.mdx) | Present |
| [Template: No-Flake](https://den.denful.dev/tutorials/noflake/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/noflake.mdx) | Present |
| [Template: NVF Standalone](https://den.denful.dev/tutorials/nvf-standalone/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/nvf-standalone.mdx) | Present |
| [Templates Overview](https://den.denful.dev/tutorials/overview/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/overview.mdx) | Present |
| [Template: Terranix Demo](https://den.denful.dev/tutorials/terranix-demo/) | [Source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/src/content/docs/tutorials/terranix-demo.mdx) | Present |

## Battery sections

The website sidebar links these sections within the battery reference.
An automatic class integration is not a value to include from `den.batteries`.
The linked section identifies its activation method and required inputs.

| Official section |
| --- |
| [define-user — OS user accounts](https://den.denful.dev/reference/batteries/#denbatteriesdefine-user) |
| [hostname — set system hostname](https://den.denful.dev/reference/batteries/#denbatterieshostname) |
| [os class — cross-platform OS config](https://den.denful.dev/reference/batteries/#os-class) |
| [user class — users.users forwarding](https://den.denful.dev/reference/batteries/#user-class) |
| [primary-user — admin privileges](https://den.denful.dev/reference/batteries/#denbatteriesprimary-user) |
| [user-shell — login shell](https://den.denful.dev/reference/batteries/#denbatteriesuser-shell) |
| [mutual-provider — host↔user config](https://den.denful.dev/reference/batteries/#denbatteriesmutual-provider) |
| [host-aspects — project host classes](https://den.denful.dev/reference/batteries/#denbatterieshost-aspects) |
| [tty-autologin — TTY auto-login](https://den.denful.dev/reference/batteries/#denbatteriestty-autologin) |
| [vm-autologin — auto-login for VMs](https://den.denful.dev/reference/batteries/#denbatteriesvm-autologin) |
| [wsl class — WSL support](https://den.denful.dev/reference/batteries/#wsl-class) |
| [forward — custom class factory](https://den.denful.dev/reference/batteries/#denbatteriesforward) |
| [import-tree — legacy module import](https://den.denful.dev/reference/batteries/#denbatteriesimport-tree) |
| [homeManager class — HM integration](https://den.denful.dev/reference/batteries/#homemanager-class) |
| [hjem class — hjem integration](https://den.denful.dev/reference/batteries/#hjem-class) |
| [maid class — nix-maid integration](https://den.denful.dev/reference/batteries/#maid-class) |
| [unfree — allow unfree packages](https://den.denful.dev/reference/batteries/#denbatteriesunfree) |
| [insecure — allow insecure packages](https://den.denful.dev/reference/batteries/#denbatteriesinsecure) |
| [inputs' — flake-parts inputs](https://den.denful.dev/reference/batteries/#denbatteriesinputs) |
| [self' — flake-parts self outputs](https://den.denful.dev/reference/batteries/#denbatteriesself) |
| [flake-scope — lib/inputs/den to pipeline](https://den.denful.dev/reference/batteries/#denbatteriesflake-scope) |

## Supporting repository documents

This table includes every tracked Markdown file outside the website content tree.
Generated fleet diagrams document the template result, not a universal topology.
Upstream contributor instructions describe work inside Den and do not replace the consuming repository's instructions.

| Document | Role |
| --- | --- |
| [.agents/skills/den-debugging/SKILL.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/.agents/skills/den-debugging/SKILL.md) | Upstream bug reproduction and regression workflow |
| [.github/ISSUE_TEMPLATE/bug_report.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/.github/ISSUE_TEMPLATE/bug_report.md) | Information requested for bug reports |
| [AGENTS.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/AGENTS.md) | Upstream development and tracing guidance |
| [CLAUDE.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/CLAUDE.md) | Pointer to upstream agent guidance |
| [README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/README.md) | Project introduction and entry links |
| [docs/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/docs/README.md) | Uncustomized Starlight starter instructions |
| [templates/bogus/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/bogus/README.md) | Template setup and examples |
| [templates/default/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/default/README.md) | Template setup and examples |
| [templates/example/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/example/README.md) | Template setup and examples |
| [templates/flake-parts-modules/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/flake-parts-modules/README.md) | Template setup and examples |
| [templates/fleet-demo/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/fleet-demo/README.md) | Template setup and examples |
| [templates/fleet-demo/diagrams/fleet/namespace.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/fleet-demo/diagrams/fleet/namespace.md) | Generated fleet diagram |
| [templates/fleet-demo/diagrams/fleet/pipe-flow.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/fleet-demo/diagrams/fleet/pipe-flow.md) | Generated fleet diagram |
| [templates/fleet-demo/diagrams/fleet/pipe-sequence.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/fleet-demo/diagrams/fleet/pipe-sequence.md) | Generated fleet diagram |
| [templates/fleet-demo/diagrams/fleet/policy-resolution.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/fleet-demo/diagrams/fleet/policy-resolution.md) | Generated fleet diagram |
| [templates/fleet-demo/diagrams/fleet/scope-topology.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/fleet-demo/diagrams/fleet/scope-topology.md) | Generated fleet diagram |
| [templates/fleet-demo/diagrams/fleet/summary.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/fleet-demo/diagrams/fleet/summary.md) | Generated fleet diagram |
| [templates/microvm/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/microvm/README.md) | Template setup and examples |
| [templates/minimal/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/minimal/README.md) | Template setup and examples |
| [templates/noflake/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/noflake/README.md) | Template setup and examples |
| [templates/nvf-standalone/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/nvf-standalone/README.md) | Template setup and examples |
| [templates/scoped-import-tree/README.md](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/templates/scoped-import-tree/README.md) | Template setup and examples |

## Releases and archived documentation

The [release index](https://github.com/denful/den/releases) contains these 19 published release records at audit time.
The [versioning guide](https://den.denful.dev/releases/) defines the archive URL scheme.
The documented `/latest/` alias returns HTTP 404 at audit time.
Only the three newest release archives below return HTTP 200.
Use each release's tagged source when its website archive is unavailable.

| Release notes | Published (UTC) | Documentation archive |
| --- | --- | --- |
| [v0.19.0](https://github.com/denful/den/releases/tag/v0.19.0) | 2026-09-24 | [v0.19.0 documentation](https://den.denful.dev/v0.19.0/) |
| [v0.18.0](https://github.com/denful/den/releases/tag/v0.18.0) | 2026-06-23 | [v0.18.0 documentation](https://den.denful.dev/v0.18.0/) |
| [v0.17.0](https://github.com/denful/den/releases/tag/v0.17.0) | 2026-05-21 | [v0.17.0 documentation](https://den.denful.dev/v0.17.0/) |
| [v0.16.0](https://github.com/denful/den/releases/tag/v0.16.0) | 2026-04-15 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.16.0) |
| [v0.15.0](https://github.com/denful/den/releases/tag/v0.15.0) | 2026-04-07 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.15.0) |
| [v0.14.0](https://github.com/denful/den/releases/tag/v0.14.0) | 2026-03-30 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.14.0) |
| [v0.13.0](https://github.com/denful/den/releases/tag/v0.13.0) | 2026-03-19 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.13.0) |
| [v0.12.0](https://github.com/denful/den/releases/tag/v0.12.0) | 2026-03-13 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.12.0) |
| [v0.11.0](https://github.com/denful/den/releases/tag/v0.11.0) | 2026-03-06 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.11.0) |
| [v0.10.0](https://github.com/denful/den/releases/tag/v0.10.0) | 2026-02-24 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.10.0) |
| [v0.9.0](https://github.com/denful/den/releases/tag/v0.9.0) | 2026-02-20 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.9.0) |
| [v0.8.0](https://github.com/denful/den/releases/tag/v0.8.0) | 2026-02-12 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.8.0) |
| [v0.7.0](https://github.com/denful/den/releases/tag/v0.7.0) | 2025-12-17 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.7.0) |
| [v0.6.0](https://github.com/denful/den/releases/tag/v0.6.0) | 2025-11-21 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.6.0) |
| [v0.5.0](https://github.com/denful/den/releases/tag/v0.5.0) | 2025-11-16 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.5.0) |
| [v0.4.0](https://github.com/denful/den/releases/tag/v0.4.0) | 2025-11-12 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.4.0) |
| [v0.3.0](https://github.com/denful/den/releases/tag/v0.3.0) | 2025-11-05 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.3.0) |
| [v0.2.0](https://github.com/denful/den/releases/tag/v0.2.0) | 2025-11-02 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.2.0) |
| [v0.1.0](https://github.com/denful/den/releases/tag/v0.1.0) | 2025-10-29 | Unavailable (HTTP 404). [Tagged source](https://github.com/denful/den/tree/v0.1.0) |

## Refresh the inventory

Compare tracked `.md` and `.mdx` files against this index at the new upstream revision.
Compare `docs/astro.config.mjs` with the battery links and page groups.
Read the release index and [heads-up discussions](https://github.com/denful/den/discussions?discussions_q=label%3Aheads-up) for upgrade notices.

Keep new pages discoverable and record renamed or removed pages.
Make sure that live links and fragments resolve.
Repeat focused evaluations for changed guidance before advancing the audit baseline.
