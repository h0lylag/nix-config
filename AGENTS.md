# Repository guidance

## Local skills

- For work involving Den (the Nix configuration framework), read
  [`.agents/skills/den/SKILL.md`](.agents/skills/den/SKILL.md). It covers Den's
  structure, aspects, entities, policies, integrations, and validation
  with primary-source references. Load its supporting references only as needed.

## Scope

- These instructions apply to the entire repository.
- This is a personal `x86_64-linux` NixOS flake managing the hosts described below.
- Keep changes focused and declarative. Do not activate, switch, boot, or deploy a
  configuration unless the user explicitly asks.

## Hosts

- `backwash` is a laptop workstation; `relic` is the primary desktop and gaming
  workstation; `343-guilty-spark` is a separate mini PC workstation and Sunshine host.
- Six Lenovo M75q hosts share `den.aspects.m75q`. Their exact Colmena membership is
  listed in `den/colmena.nix`.
- `midship` is the public nginx/TLS edge. It proxies services on `coagulation` and
  runs other services locally.
- `ascension` is an OVH/OpenStack VPS providing SSH and Tailscale access.
- `turf` is a single-disk VPS targeted as the M75q Tailscale exit node.
- `coagulation` is the rackmount homelab server for ZFS storage, NixOS containers,
  a Podman runtime, and libvirt Windows guests.
- `warlock` is an Oracle Cloud free-tier VPS and distributed-build client.

## Networking

- Every Den host and active NixOS container enables Tailscale. The Windows libvirt
  guests run Tailscale inside the guests; their guest software is outside this flake.
  Preserve private connectivity when adding or changing nodes.
- Account for tailnet connectivity when changing firewall rules, DNS, routing, service
  bind addresses, or access controls. Do not assume inter-node traffic only uses the LAN
  or public interfaces.

## Repository layout

- `flake.nix` declares inputs and exports Den's flake outputs; `flake.lock` pins
  input revisions.
- `den/default.nix` explicitly imports the framework, schema, hosts, and aspects.
  It applies the hostname battery and base aspect to every Den host through
  `den.schema.host.includes`. Each host opts into common explicitly; the six M75q
  hosts do so through their shared aspect. `den/schema.nix` enables strict mode for
  host, user, and home entities; declare custom entity options there.
- `den/schema.nix` owns the shared NixOS builder and typed host `nixpkgs` and
  `specialArgs` options. Stable nixpkgs is the default; relic selects unstable.
- `den/colmena.nix` exports the Colmena hive for the six M75q cluster hosts,
  excluding `343-guilty-spark`. It reuses Den host modules and nixpkgs metadata;
  builds run through the deploying machine. The CLI lives in the workstation aspect.
- `hosts/<name>/default.nix` is an outer Den module combining the machine
  declaration, host aspect selection, and host-local NixOS configuration.
  `hosts/coagulation/containers/den.nix` selects active containers. The six M75q
  hosts share `hosts/m75q-hardware-common.nix` and `hosts/m75q-disko-common.nix`.
- `den/aspects/` owns shared configuration bundles, including base/common,
  workstation/gaming, distributed-build clients, package configuration, Tailscale, and
  SOPS age-key setup. The SOPS age-key aspect owns the upstream SOPS module import.
- Each host explicitly declares `users.chris`. `users/chris/default.nix` owns the
  shared account through Den's `user` class, opts into `host-aspects` projection,
  and imports the shared Home Manager configuration. Workstation account settings
  live in `workstation.user`; coagulation's extra groups live in its host aspect's
  `user` class. Backwash, relic, and `343-guilty-spark` opt into host-managed Home
  Manager; relic selects the unstable Home Manager and nixpkgs inputs.
- Keep hardware, disk layout, networking, services, containers, and VM
  definitions under the relevant host directory. Hardware and service files,
  including individual container entry points, are plain NixOS modules.
  Each host's local NixOS module is the first inline `nixos.imports` item, before
  upstream integrations.
- `modules/` contains configurable NixOS modules with their own option namespaces.
- `pkgs/<name>/package.nix` contains custom package recipes. `overlays/local.nix`
  discovers them as `pkgs.local.<name>`; explicit entries handle exceptions.
  `overlays/default.nix` catalogs source and local overlays, plus scoped replacements
  and fixes; Den aspects select which to apply. Read `overlays/README.md` before
  changing this layout.
- `secrets/` contains SOPS-encrypted files. Recipient and creation rules live in
  `.sops.yaml`.

## Conventions

- In shared aspects, prefer `lib.mkDefault` for values that a host may reasonably override.
  Reusable modules should use typed options, `lib.mkEnableOption`, and
  `lib.mkIf cfg.enable` where appropriate.
- Add new module files to the relevant `imports` list. Shared Den aspects should
  capture flake inputs through their outer module arguments. For host-local NixOS
  modules that need inputs, declare only those arguments in the host entity's
  `specialArgs`.
- Use aspect `includes` for Den composition and `nixos.imports` for NixOS modules.
  Containers remain separate nested NixOS evaluations: container-base imports
  the packages, Tailscale, and SOPS age-key NixOS modules explicitly. The SOPS
  age-key module already imports upstream SOPS. Do not assume host aspect
  composition or host arguments automatically propagate into containers.
- Container-base resolves the Chris aspect's `user` class explicitly into a
  `users.users.chris` submodule function. Containers are not Den host/user entities;
  their service-specific account additions remain in their own NixOS modules.
  Do not import raw Den class-content wrappers into ordinary account submodules.
- Keep package sources reproducible: pin revisions and update fixed-output hashes
  together. Preserve the rationale for upstream or hardware workarounds.
- Do not change `system.stateVersion` during routine upgrades. Treat generated
  `hardware-configuration.nix` and `disko.nix` files as host-specific and edit them only
  when the requested hardware or disk layout change requires it.
- Do not hand-edit encrypted secret payloads or commit plaintext credentials. Use
  `sops secrets/<file>` and update `.sops.yaml`/recipient keys when necessary.
- Change `flake.lock` only when intentionally updating flake inputs.

## Tooling

- [`comma`](https://github.com/nix-community/comma) is available on hosts through
  `den/aspects/common.nix`. Use `, <command> [args...]` to run needed one-off tools from
  nixpkgs without installing them or adding them to the configuration.
- `scripts/m75q.sh` handles M75q wake, discovery, deployment, and remote commands;
  `den/colmena.nix` defines the deployment hive.
- Keep tools required by a host or service declarative in the appropriate aspect, host,
  or package; use `comma` only for transient agent and maintenance work.

## Nix MCP

- The Nix MCP server provides current nixpkgs package and channel information, NixOS
  options, flake inputs, binary-cache/store queries, and Nix documentation. Prefer it to
  memory or general web search for these topics.
- Query the channel that matches the input being changed; this flake uses stable,
  unstable, and explicitly pinned release inputs. Use the MCP's `nix_versions` tool when
  package history or an exact nixpkgs commit matters. The local flake and module graph
  remain authoritative and must still be validated locally.

## Validation

- For Nix changes, run `scripts/check-config.sh`. It checks changed-file formatting,
  runs `nix flake check --no-build --no-write-lock-file`, evaluates every host and
  nested container derivation, and verifies Colmena membership, deployment settings,
  and derivation equality with Den hosts. Diagnostics go to stderr; stdout contains
  a JSON derivation snapshot. Formatting defaults to changes relative to `HEAD`;
  pass another base ref to include committed changes. New imported Nix files must
  be visible to Git (for example, with `git add --intent-to-add`).
- For structural Den changes, compare snapshots from before and after the change.
  Inspect full `system.build.toplevel.drvPath` values for affected hosts and nested
  containers; the flake check alone may not force nested evaluation. Investigate
  ordering differences, since unchanged package versions do not prove identical
  outputs.
- Distinguish evaluation, actual builds, and user-reported runtime results.
- For changes that merit a real system build, build the affected host without activating
  it:

  ```sh
  nh os build --hostname <host> .
  ```
