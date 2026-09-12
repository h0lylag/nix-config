# Sources and revision caveats

Researched **2026-09-12** using Den's official documentation and a checkout of
[`denful/den` at `d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d`](https://github.com/denful/den/tree/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d).
These notes are an original synthesis with original illustrative examples, not
a vendored copy of the manual. Links below are primary sources.

## Version selection

The [versioning page](https://den.denful.dev/releases/) distinguishes development
main (unversioned documentation), the moving `latest` release tag, and specific
release documentation under `/<version>/`. This skill's baseline is a specific
main revision, not a claim about the latest release. Recheck the consumer's
`flake.lock` and that revision's documentation/source before applying APIs.

Documentation source is stored under `docs/src/content/docs/`. For reproducible
research, replace the moving website page with its `.mdx` (or `.md` for debug)
under this immutable
[documentation tree](https://github.com/denful/den/tree/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/docs/src/content/docs).
For example, the original user-provided page corresponds to
[core-principles.mdx at the research revision](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/docs/src/content/docs/explanation/core-principles.mdx).

## Reading map

| Task | Original documentation |
| --- | --- |
| Understand the model | [Core principles](https://den.denful.dev/explanation/core-principles/), [library versus framework](https://den.denful.dev/explanation/library-vs-framework/) |
| Declare entities and shared metadata | [Entities](https://den.denful.dev/explanation/entities/), [schema API](https://den.denful.dev/reference/schema/), [host/user guide](https://den.denful.dev/guides/declare-hosts/) |
| Compose features | [Aspects](https://den.denful.dev/explanation/aspects/), [configure aspects](https://den.denful.dev/guides/configure-aspects/), [aspect API](https://den.denful.dev/reference/aspects/) |
| Understand scope and arguments | [Parametric aspects](https://den.denful.dev/explanation/parametric/), [class modules](https://den.denful.dev/explanation/class-modules/) |
| Wire or migrate a flake | [From flake to Den](https://den.denful.dev/guides/from-flake-to-den/), [migration](https://den.denful.dev/guides/migrate/), [minimal template](https://den.denful.dev/tutorials/minimal/), [outputs](https://den.denful.dev/reference/output/) |
| Configure users and home environments | [Home environments](https://den.denful.dev/guides/home-manager/), [batteries](https://den.denful.dev/reference/batteries/) |
| Route between entities | [Policies](https://den.denful.dev/explanation/policies/), [activation](https://den.denful.dev/explanation/policy-activation/), [effect API](https://den.denful.dev/reference/policies/), [mutual configuration](https://den.denful.dev/guides/mutual/) |
| Aggregate structured data | [Quirks explanation](https://den.denful.dev/explanation/quirks-and-pipes/), [pipe guide](https://den.denful.dev/guides/quirks/), [quirk API](https://den.denful.dev/reference/quirks/), [fleets](https://den.denful.dev/explanation/fleet/) |
| Extend or share | [Custom classes](https://den.denful.dev/guides/custom-classes/), [namespaces](https://den.denful.dev/guides/namespaces/), [angle brackets](https://den.denful.dev/guides/angle-brackets/) |
| Diagnose evaluation | [Debugging](https://den.denful.dev/guides/debug/), [structural introspection](https://den.denful.dev/explanation/structural-introspection/), [capture/diagrams](https://den.denful.dev/reference/diag/) |
| Upgrade older APIs | [den.ctx migration](https://den.denful.dev/guides/migrate-ctx/), [deprecated helpers](https://den.denful.dev/reference/lib-deprecated/) |

Read detailed references as a task requires; the skill deliberately does not
duplicate every internal effect handler, battery parameter, or graph renderer.
For MicroVM/Terranix or other specialized domains, inspect the corresponding
[upstream templates](https://github.com/denful/den/tree/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/templates)
and their inputs instead of generalizing from an OS example.

## Verified discrepancies in the documentation

### Entity `.aspect` is an aspect value

Some introductory tables call it a name, and some snippets use
`den.aspects.${host.aspect}` or `den.aspects.${user.aspect}`. At the research
revision it is a `raw` option defaulting to the looked-up aspect object. Prefer
`host.aspect` or `user.aspect` directly. Evidence:
[host/user option implementation](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/nix/lib/entities/host.nix),
[lookup helper](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/nix/lib/entities/_types.nix).

### Missing entity arguments do not always mean "skip"

The core-principles overview simplifies dispatch to argument presence. The more
specific parametric documentation describes descendant fan-out, emitting at the
original scope. Host-level `homeManager` content does not automatically reach
users, including when an aspect binds each descendant user. Evidence:
[parametric documentation at the revision](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/docs/src/content/docs/explanation/parametric.mdx),
[host/HM scope regression tests](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/templates/ci/modules/deadbugs/issue-609-host-scope-hm-leak.nix),
[per-user OS emission tests](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/templates/ci/modules/features/user-scoped-host-class-fanout.nix).

### Standalone homes have more context than older tables suggest

The schema reference describes null unbound users/hosts, but the implementation
now synthesizes user identity for standalone homes and minimal host identity for
external `user@host` names. It keeps the full home key for output/scope identity
even though `home.name` is the parsed user name. These synthetic values do not
provide all declared entity fields or an OS configuration. Evidence:
[home implementation](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/nix/lib/entities/home.nix),
[standalone user binding tests](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/templates/ci/modules/deadbugs/issue-640-standalone-home-user-arg.nix).

### Route paths and enrichment need the detailed effect semantics

The custom-class guide says route uses `path`, not `intoPath`; the detailed
policy reference now documents `intoPath` as an alias, rejecting both together.
Likewise a short `resolve` description says "new scope", but non-entity-only
bindings enrich the existing scope. The skill uses `path` and distinguishes
enrichment from entity resolution. Evidence:
[policy reference at the revision](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/docs/src/content/docs/reference/policies.mdx),
[effect constructors](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/nix/lib/policy-effects.nix),
[policy explanation](https://den.denful.dev/explanation/policies/).

### Tutorial snippets are not complete migration patches

Some guides assume inputs or lexical variables established elsewhere, contain
illustrative option names, or show minimal hardware placeholders. Verify each
borrowed example in its enclosing evaluator; do not copy placeholder disks,
global state versions, administrator privileges, or incomplete `specialArgs`
into a consumer's configuration. The skill's integration example is explicitly an
evaluation example, not a bootable configuration.

## Validation evidence

- Validated the skill frontmatter and naming with the skill-creator validator.
- Checked relative links and primary-source targets against the researched
  checkout; parsed all 10 fenced Nix examples.
- Evaluated the bootstrap and quirk examples with this exact Den revision and
  the repository's pinned nixpkgs. Checked the generated host label, assembled
  quirk value, aspect value type, descendant user fan-out, and named policy
  inclusion for two users. An initial anonymous static policy emission lost a
  user's contribution; the policy reference records the verified named-module
  pattern. This was an evaluation check, not a bootable system build.
- The follow-up audit evaluated **118 upstream regression cases**, all passing,
  across 21 selected test files. Coverage included Home Manager and standalone
  homes, required context and class injection, policy activation/exclusion and
  enrichment, custom forwarding, import-tree, schemas, descendant fan-out, and
  cross-host pipe isolation. No expected-error cases were skipped. Tests used
  the [upstream CI lockfile](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/templates/ci/flake.lock),
  including nixpkgs `64c08a7ca051951c8eae34e3e3cb1e202fe36786` and Home Manager
  `61e2c9659324181e0f0ed911958c536333b1d4f6`.
- A separate integration check wrapped six existing NixOS configurations in
  temporary Den host aspects while retaining their legacy modules, builders,
  and arguments. All six resulting system derivation paths matched their
  originals; eleven nested containers retained their state versions and
  Tailscale enablement. This was evaluation evidence for the legacy-module
  integration pattern, not a migration or activation of those systems.
- Consumer flake evaluation passed separately. No system builds, runtime
  hardware tests, or exhaustive checks of every optional Den integration were
  performed. The skill does not claim those broader guarantees.
