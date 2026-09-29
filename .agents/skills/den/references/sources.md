# Sources and revision caveats

Audited on 2026-09-29 using the official website, release records, and Den source.
The [complete documentation index](official-documentation.md) covers every documentation page and supporting Markdown file at the audited main revision.
These references summarize behavior and link original sources. They do not copy the manual.

## Revision selection

| Scope | Revision | Meaning |
| --- | --- | --- |
| Current main | [`7594405b45e0ce2d5a418fe104a26e17f6b1dd8f`](https://github.com/denful/den/tree/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f) | Main at audit time, committed 2026-09-28 |
| Latest release | [`v0.19.0`, `37eb88ce28a9e42d5b367b967a9097030ff4f665`](https://github.com/denful/den/releases/tag/v0.19.0) | Released 2026-09-24, before several main fixes |
| Repository pin | [`d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d`](https://github.com/denful/den/tree/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d) | Still selected by this repository's `flake.nix` and `flake.lock` |

The unversioned website follows main. The versioning page describes `/latest/` and `/<version>/` release archives.
At audit time, `/latest/` and archives through `v0.16.0` return HTTP 404.
Archives for `v0.17.0`, `v0.18.0`, and `v0.19.0` return HTTP 200.
Use the tagged repository source when a documented archive is unavailable.
A newer explanation can describe behavior that the consumer pin does not support.
Match documentation and source to the consumer before changing configuration.
[Versioning](https://den.denful.dev/releases/).

## Changes since the repository pin

| Area | Pinned behavior | Current behavior and evidence |
| --- | --- | --- |
| User and home aspect lookup | Bare user aspect only | Qualified and bare aspects compose. [Lookup source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/nix/lib/entities/_types.nix) |
| `home.name` | Parsed user name, with separate scope identity | Full registry key, such as `alice@demo`. Use `home.userName` for the account. [Home source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/nix/lib/entities/home.nix) |
| Aspect origin metadata | `meta.provider` | `meta.aspect-chain`. Old freeform metadata can be accepted but ignored. [Aspect reference](https://den.denful.dev/reference/aspects/#metaaspect-chain) |
| Entity definitions across modules | List and scalar conflicts can silently drop definitions | Lists concatenate. Conflicting scalar definitions fail. [Fix](https://github.com/denful/den/commit/20d1e76) |
| Schema dependency | Direct `gen-schema` input or pinned fallback | `inputs.gen` hub or pinned fallback. [Schema source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/nix/lib/schema.nix) |
| Nested aspects and guards | Earlier identity and membership behavior | Fixes for duplicate includes, nested membership, and forwarded providers. [Identity fix](https://github.com/denful/den/commit/85b4e52), [nested-aspect fix](https://github.com/denful/den/commit/ba9ee3a) |
| `flakeOutputs.all` | Invalid outer-module `includes` key | Fixed to `imports` after `v0.19.0`. [Fix](https://github.com/denful/den/commit/6cceca4) |
| Unused WSL integration | Can force a missing `inputs.nixos-wsl` in affected evaluations | Optional when unused, fixed after `v0.19.0`. [Fix](https://github.com/denful/den/commit/71dff3a) |
| Providers registered late in user resolution | Can miss delivery | Main fires these providers, fixed after `v0.19.0`. [Fix](https://github.com/denful/den/commit/7594405) |

These are compatibility notes, not instructions to upgrade this repository.
Do not apply all main behavior to `v0.19.0` merely because the website is newer.
Before an upgrade, read the intervening release notes and compare evaluated outputs.

## Documentation conflicts and practical limits

### Entity values and synthetic identities

An entity's `.aspect` is an aspect value, not a string for another lookup.
Use `host.aspect` or `user.aspect` directly when an API expects an aspect.
Older snippets with `den.aspects.${user.aspect}` do not match the implementation.

Standalone homes synthesize user identity when no declared host user exists.
An external `user@host` home also gets a minimal host containing `name` and `system`.
That host has no `class` or `hostName`, and it does not supply `osConfig`.
The schema table still describes some standalone values as null, so inspect the implementation.
[Current home source](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/nix/lib/entities/home.nix),
[pinned home source](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/nix/lib/entities/home.nix).

### Binding and delivery

Missing entity arguments do not always make an aspect inert.
An aspect can bind descendant entities while emitting at its original scope.
Host-scope `homeManager` and `user` content do not automatically configure descendant users.
Use the destination table and explicit routing.
[Parametric rule](https://den.denful.dev/explanation/parametric/),
[class destinations](https://den.denful.dev/explanation/where-config-lands/).

Direct host children named after users can reach every user on that host.
Use `provides.<user>` when targeting one user.
Upstream also labels untargeted user-scope OS delivery as an isolation bug.
Use the `user` class for account settings and explicit host providers for other OS settings.
Do not invent the proposed `user-aspects` battery.
[Current behavior and caveats](https://den.denful.dev/explanation/where-config-lands/),
[issue 694](https://github.com/denful/den/issues/694).

### Strict mode

The blanket strict module includes `den.schema.aspect = den.lib.strict`.
A probe with ordinary `den.aspects.demo.nixos` content fails at both audited revisions.
The narrower host/user/home schema setup preserves class content and rejects undeclared entity metadata.
Keep the repository's existing setup unless a focused evaluation proves another approach.
[Strict module](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/nix/strict.nix).

### Library dependencies

Den has no declared flake inputs, but it fetches libraries during evaluation.
Both recorded revisions load nix-effects from a consumer input or pinned fallback.
Current main loads schemas through the gen hub. The consumer pin loads gen-schema directly.
The site's broad dependency statement does not describe these implementation requirements.
The complete gen redesign remains planned work.
[Effects loader](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/nix/lib/fx.nix),
[schema loader](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/nix/lib/schema.nix),
[future direction](https://den.denful.dev/future/).

### Effects, batteries, and examples

The route effect accepts `path` or the `intoPath` alias, but rejects both together.
The custom-class guide's shorter wording omits the alias.
A `resolve` with only non-entity bindings enriches the current scope.
It does not create a new entity scope.
[Effect constructors](https://github.com/denful/den/blob/7594405b45e0ce2d5a418fe104a26e17f6b1dd8f/nix/lib/policy-effects.nix).

Automatic integrations such as `os` and `user` are classes, not selectable battery values.
Current documentation corrects several older battery headings.
Use host metadata to enable optional integrations and their actual class keys for content.
[Battery reference](https://den.denful.dev/reference/batteries/).

Tutorials and case studies contain assumptions, helper code, and hardware examples.
Read their enclosing module and input declarations before adapting snippets.
Preserve the consumer's hardware, privileges, state versions, network access, and nested evaluation boundaries.

## Audit evidence

The 2026-09-29 audit inventories 74 website pages, all returning HTTP 200.
The index also includes the repository's supporting Markdown files and all 19 published release notes.
Coverage comes from tracked files, the website sidebar, and the GitHub releases API.
Source links use immutable commits where implementation details matter.

The audit evaluates original skill examples and focused behavior probes against both recorded revisions.
Both runs use this repository's pinned nixpkgs and Home Manager sources.
The bootstrap host label is `demo`, and the assembled inventory quirk is `example` on both.
The home-name and qualified-aspect probes reproduce the version differences above.
Both revisions reproduce the blanket strict-mode failure.
Twelve behavior assertions pass on each revision, for 24 passing assertions in total.
They cover named policies for two users, optional children, descendant binding, Home Manager scope, explicit providers, and carried overlay functions.
They also cover entity strictness, sibling collection, entity-kind predicates, and package output routing.
All ten fenced Nix examples parse. Local links, live fragments, and immutable source paths resolve.
The catalog accounts for all 96 tracked Markdown files in the official repository.
The skill-creator validator passes for the updated skill.

These are documentation and evaluation checks, not system builds or runtime results.
The audit does not claim exhaustive regression coverage of Den or its optional integrations.
The earlier skill's 2026-09-12 regression and migration results are historical, not rerun results for current main.
