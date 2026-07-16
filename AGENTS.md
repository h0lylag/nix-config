# Repository guidance

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
- `coagulation` is the rackmount homelab server: it manages the ZFS storage array and
  runs NixOS containers, libvirt virtual machines, and a few
  Docker-compatible Podman containers.
- `warlock` is an Oracle Cloud free-tier VPS with few current responsibilities.

## Networking

- Every host, NixOS container, and virtual machine runs Tailscale for private inter-node
  communication. Preserve this invariant when adding or changing nodes.
- Account for tailnet connectivity when changing firewall rules, DNS, routing, service
  bind addresses, or access controls. Do not assume inter-node traffic only uses the LAN
  or public interfaces.

## Repository layout

- `flake.nix` pins inputs and defines `nixosConfigurations`.
- `hosts/<name>/default.nix` is a host entry point. Keep hardware, disk layout, and
  host-only services, containers, and networking under that host directory.
- `profiles/` contains shared layered machine roles: `base`, `common`, `workstation`, and
  `gaming`. `features/` contains smaller reusable opt-in bundles, while `modules/`
  contains configurable NixOS modules with their own option namespaces.
- `pkgs/<name>/package.nix` contains custom packages, normally consumed with
  `pkgs.callPackage`.
- `secrets/` contains SOPS-encrypted files. Recipient and creation rules live in
  `.sops.yaml`.

## Conventions

- In profiles, prefer `lib.mkDefault` for values that a host may reasonably override.
  Reusable modules should use typed options, `lib.mkEnableOption`, and
  `lib.mkIf cfg.enable` where appropriate.
- Add new files to the relevant `imports` list. If they require a flake input, also wire
  that input through `specialArgs` for every host that imports them.
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
  `profiles/common.nix`. Use `, <command> [args...]` to run needed one-off tools from
  nixpkgs without installing them or adding them to the configuration.
- Keep tools required by a host or service declarative in the appropriate profile, host,
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

- For changes that merit a real system build, build the affected host without activating
  it:

  ```sh
  nh os build --hostname <host> .
  ```
