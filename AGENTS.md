# Repository guidance

## Local skills

- For work involving Den (the Nix configuration framework), read
  [`.agents/skills/den/SKILL.md`](.agents/skills/den/SKILL.md). It covers Den's
  structure, aspects, entities, policies, integrations, migration, and validation
  with primary-source references. Load its supporting references only as needed.

## Scope

- These instructions apply to the entire repository.
- This is a personal `x86_64-linux` NixOS flake managing the hosts described below.
- Keep changes focused and declarative. Do not activate, switch, boot, or deploy a
  configuration unless the user explicitly asks.

## Hosts

- `backwash` is a laptop workstation.
- `relic` is the primary desktop and gaming workstation.
- `midship` is a small VPS. Its main role is to proxy public traffic to services running
  in containers and virtual machines on `coagulation`.
- `ascension` is an OVH/OpenStack VPS currently providing SSH and Tailscale access.
- `coagulation` is the rackmount homelab server: it manages ZFS storage, eleven
  active NixOS container configurations, and libvirt virtual machines. Its Podman
  runtime is configured, but the declarative OCI-container imports are disabled.
  The Zanzibar NixOS container is also disabled.
- `warlock` is an Oracle Cloud free-tier VPS with few current responsibilities.

## Networking

- Every host, NixOS container, and virtual machine runs Tailscale for private inter-node
  communication. Preserve this invariant when adding or changing nodes.
- Account for tailnet connectivity when changing firewall rules, DNS, routing, service
  bind addresses, or access controls. Do not assume inter-node traffic only uses the LAN
  or public interfaces.

## Repository layout

- `flake.nix` declares inputs and exports the Den evaluator's flake outputs;
  `flake.lock` pins their revisions.
- `den/default.nix` explicitly imports the framework, schema, hosts, and aspects.
- `den/schema.nix` owns the shared NixOS builder and typed host `nixpkgs` and
  `specialArgs` options. Stable nixpkgs is the default; relic selects unstable.
- `hosts/<name>/default.nix` is an outer Den module combining the machine
  declaration, host aspect selection, and host-local NixOS configuration.
  `den/hosts/` is retired. `hosts/coagulation/containers/den.nix` is the outer
  Den module selecting active containers.
- `den/aspects/` owns shared configuration bundles, including base/common,
  workstation/gaming, Tailscale, and SOPS age-key setup. `profiles/` and `features/`
  are retired.
- Keep hardware, disk layout, networking, services, containers, and VM
  definitions under the relevant host directory. Existing hardware and service
  files, including individual container entry points, remain plain NixOS modules.
  The combined host entry preserves its local NixOS module as the first inline
  `nixos.imports` item before upstream integrations, retaining merge order.
- `modules/` contains configurable NixOS modules with their own option namespaces.
  `modules/geoip-block.nix` remains unimported; its option namespace is still
  `features.geoip-block`.
- `pkgs/<name>/package.nix` contains custom packages, normally consumed with
  `pkgs.callPackage`.
- `secrets/` contains SOPS-encrypted files. Recipient and creation rules live in
  `.sops.yaml`.
- `docs/nix-to-den.md` records the migration and validation history. `docs/` is
  currently Git-ignored; updating this local record does not include it in commits.

## Conventions

- In shared aspects, prefer `lib.mkDefault` for values that a host may reasonably override.
  Reusable modules should use typed options, `lib.mkEnableOption`, and
  `lib.mkIf cfg.enable` where appropriate.
- Add new files to the relevant `imports` list. Shared Den aspects should capture
  flake inputs through their outer module arguments. For host-local NixOS modules
  that need inputs, declare only those arguments in the host entity's `specialArgs`.
- Use aspect `includes` for Den composition and `nixos.imports` for NixOS modules.
  Containers remain separate nested NixOS evaluations: container-base imports
  the Tailscale and SOPS age-key NixOS module functions explicitly. Do not assume
  host aspect composition or host arguments automatically propagate into containers.
- Keep package sources reproducible: pin revisions and update fixed-output hashes
  together. Preserve useful comments around temporary upstream or hardware workarounds.
- Do not change `system.stateVersion` during routine upgrades. Treat generated
  `hardware-configuration.nix` and `disko.nix` files as host-specific and edit them only
  when the requested hardware or disk layout change requires it.
- Do not hand-edit encrypted secret payloads or commit plaintext credentials. Use
  `sops secrets/<file>` and update `.sops.yaml`/recipient keys when necessary.
- Change `flake.lock` only when intentionally updating flake inputs.

## Tooling

- [`comma`](https://github.com/nix-community/comma) is available through
  `den/aspects/common.nix`. Use `, <command> [args...]` to run needed one-off tools from
  nixpkgs without installing them or adding them to the configuration.
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

- Check formatting of touched Nix files:

  ```sh
  nixfmt --check path/to/file.nix
  ```

- Evaluate every active NixOS configuration without building it:

  ```sh
  nix flake check --no-build --no-write-lock-file
  ```

- For structural Den changes, compare full `system.build.toplevel.drvPath` values
  before and after for affected hosts and nested containers. The no-build flake
  check alone may not force errors in nested configurations. Investigate ordering
  differences; unchanged package versions alone do not prove identical outputs.
- Distinguish evaluation, actual builds, and user-reported runtime results. Update
  the migration record when changing Den structure or recording migration status.
- For changes that merit a real system build, build the affected host without activating
  it:

  ```sh
  nh os build --hostname <host> .
  ```
