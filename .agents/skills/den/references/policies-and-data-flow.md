# Policies and data flow

Read [Structure and aspects](structure-and-aspects.md) first if entity scope and
module class are unclear. APIs below target the revision in [sources.md](sources.md).

## Register and activate a policy

Policies are context functions returning lists of effect values. Den wraps
registered policies so an `includes` list can distinguish them from aspects.
Registration in `den.policies` does not activate a custom policy.

This original example delivers a named aspect to declared user scopes:

```nix
{ den, ... }:
{
  den.aspects.shell-tools.homeManager.programs.helix.enable = true;
  den.policies.user-tools = { user, ... }: [
    (den.lib.policy.include den.aspects.shell-tools)
  ];
  den.schema.user.includes = [ den.policies.user-tools ];
}
```

For unconditional inclusion on every user, including the aspect directly is
simpler. A policy becomes useful when it expresses relationships, predicates,
enrichment, or delivery beyond ordinary composition.
[Policies](https://den.denful.dev/explanation/policies/),
[activation](https://den.denful.dev/explanation/policy-activation/).

For per-user OS settings delivered by a policy, prefer a named aspect whose
`nixos` module explicitly requests `{ user, ... }`. Den uses declared entity
arguments when keying class content. A policy that closes over `user` and emits
anonymous static OS content can lose another user's contribution through
deduplication. Check at least two users when changing this pattern.
[Per-user class identity regression tests](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/templates/ci/modules/features/user-scoped-host-class-fanout.nix).

Policies activated at a scope are available to descendants; required arguments
control where they can fire. Use `policy.for entity policy` for entity identity
or `policy.when predicate policy` for a condition. Match entities through these
helpers/`id_hash`, not whole-record equality. Parent policy exclusions dominate
child inclusion, including through `for`/`when` wrappers.

## Pick the intended effect

| Effect | Meaning |
| --- | --- |
| `policy.resolve { flag = value; }` | With non-entity keys, enrich context in the current scope |
| `policy.resolve.to "kind" bindings` | Resolve an entity in a child scope |
| `policy.resolve.shared bindings` | Shared, non-isolated entity fan-out; used by built-in host-to-user traversal |
| `policy.include aspect` | Walk an aspect, including nested composition and constraints |
| `policy.provide { class; module; }` | Deliver a raw module directly to a class |
| `policy.route { fromClass; intoClass; path; }` | Route collected class content into a target class/path |
| `policy.deliver { from; to; at; mode; }` | Explicit delivery primitive underlying route/provide |
| `policy.instantiate entity` | Request output construction using the entity's builder and output path |
| `policy.pipe.from name stages` | Build a pipe over a named quirk |

`deliver.mode` supports `merge`, `nest`, and `verbatim`; the last preserves class
module wrappers for a target that re-evaluates them, such as a nested VM module.
Do not substitute modes casually. `route`/`provide` remain supported convenience
APIs. Prefer `path` in route examples; `intoPath` is an alias at this revision,
and supplying both is an error. `forward` has its own item-function API.
[Effect signatures](https://den.denful.dev/reference/policies/).

The framework already activates its core traversal policies. Do not redeclare
`host-to-users` just to add user configuration. When introducing a genuinely new
entity kind, define its schema and intended parent relationship, activate the
custom traversal where it should begin, and verify output scope/instantiation.
[Schema](https://den.denful.dev/reference/schema/),
[core traversal source](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/modules/policies/core.nix).

## Cross-entity provides and host projection

Built-in providers support host-to-user and user-to-host delivery:

```nix
{
  den.aspects.demo.provides.to-users.homeManager.programs.helix.enable = true;
  den.aspects.demo.provides.alice.homeManager.programs.vim.enable = true;
  den.aspects.alice.provides.to-hosts.nixos.environment.variables.EDITOR = "vim";
}
```

`to-users` targets users on the host; a named user provider targets that user.
Conversely `to-hosts` and named host providers route from a user to its hosts.
These are built-in cross-entity semantics, distinct from ordinary named child
aspects. The documentation recommends explicit policies for new complex delivery
while retaining these providers as a supported API.
[Configure aspects](https://den.denful.dev/guides/configure-aspects/#cross-entity-provides),
[mutual configuration](https://den.denful.dev/guides/mutual/).

If the desired behavior is to project the host's entire aspect tree for a user's
classes, include `den.batteries.host-aspects` on that user. This is broader than
forwarding one chosen feature. Verify the intended Home Manager result on each
user; host-level `homeManager` content otherwise stays at the wrong emission
scope. [Host projection source](https://github.com/denful/den/blob/d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d/modules/aspects/batteries/host-aspects.nix).

## Quirks: structured data, then optional routing

Register a quirk in `den.quirks`; otherwise an aspect key can be interpreted as
a class instead of structured data. Quirk names cannot collide with class names.
Producers emit values under that key. Consumers request the quirk as a class
module argument and receive the scope's assembled list, empty when no producer
contributes. Same-scope aggregation requires no custom pipe policy.

This original example writes an inventory file without changing firewall access:

```nix
{ den, ... }:
{
  den.quirks.service-notes.description = "Service inventory entries";
  den.aspects.notes-producer.service-notes = { label = "example"; };
  den.aspects.notes-consumer.nixos = { service-notes, lib, ... }: {
    environment.etc."service-notes".text =
      lib.concatMapStringsSep "\n" (entry: entry.label) service-notes;
  };
  den.aspects.demo.includes = [
    den.aspects.notes-producer
    den.aspects.notes-consumer
  ];
}
```

Include order does not determine whether the consumer sees a producer. Assembly
occurs after the walk. Use ordinary NixOS options for simple direct settings;
quirks help when multiple producers should remain independent of the consumer
or when data must cross scopes.
[Quirks explanation](https://den.denful.dev/explanation/quirks-and-pipes/).

## Pipes and fleets

Custom pipe policies must also be activated through `includes`.
`pipe.filter` selects entries; `pipe.transform` maps them; `pipe.as` delivers
under another registered quirk name; `pipe.expose` makes child data available to
its parent. `pipe.collect predicate` gathers matching sibling scopes.
`pipe.withProvenance` changes entries into `{ value; source; }` records so the
consumer can identify their original context.
[Pipe guide](https://den.denful.dev/guides/quirks/),
[quirk reference](https://den.denful.dev/reference/quirks/).

The default tree is flake → system → hosts/homes → host users. Hosts on the same
system share a parent and can collect each other's data. Do not assume hosts
under different system parents are siblings. Customized fleet grouping needs
deliberate topology and output handling, including checking whether default
traversal would create duplicate paths.

Quirk thunks can read a producing configuration through `{ config, ... }`.
Cross-host collection evaluates such data against its source configuration;
mutually dependent host configurations can cause infinite recursion. Model data
dependencies as an acyclic graph. Endpoint data still needs to match the actual
network routes and service bind/access rules.
[Fleets](https://den.denful.dev/explanation/fleet/).

## Custom classes

Use `den.batteries.forward` when a new class should map to an existing module
path. Its key parameters are `each`, `fromClass`, `intoClass`, `intoPath`, and
`fromAspect`; the latter four generally map each item to a value. When the item
is a user entity, return `user.aspect` directly, not
`den.aspects.${user.aspect}`. Check the exact revision for optional guards,
argument adapters, and class registration/default forwarding behavior.

For a class needing its own builder/output, register the class and use an
appropriate instantiation policy rather than pretending an arbitrary key is a
NixOS module. Upstream MicroVM and Terranix templates demonstrate specialized
integrations; inspect their source before adapting them.
[Custom classes](https://den.denful.dev/guides/custom-classes/),
[MicroVM template](https://den.denful.dev/tutorials/microvm/),
[Terranix template](https://den.denful.dev/tutorials/terranix-demo/).
