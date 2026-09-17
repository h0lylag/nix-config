# NixOS Configs

This repository contains my personal collection of [NixOS](https://nixos.org/) configuration files. It is used to manage and deploy my machines.

## M75q cluster deployment

[Colmena](https://colmena.cli.rs/unstable/tutorial/flakes.html) manages the six
M75q hosts listed in [`den/colmena.nix`](den/colmena.nix). `343-guilty-spark` is
excluded. The hive reuses each host's Den module, pinned nixpkgs, and special
arguments. Builds run through the deploying machine's Nix daemon
(`deployment.buildOnTarget = false`), using any configured distributed builders.

The CLI is installed by the workstation aspect. From this repository, you can
also use the pinned CLI immediately through `nix run .#colmena --`:

```sh
# Evaluate the hive without building or deploying.
nix run .#colmena -- eval -E '{ nodes, ... }: builtins.attrNames nodes'

# Build the cluster configurations without deploying.
nix run .#colmena -- build --on @m75q

# Deploy and activate the cluster configurations.
nix run .#colmena -- apply --on @m75q

# Deploy a single node.
nix run .#colmena -- apply --on 001-shamed-instrument
```

Targets use their Tailscale MagicDNS hostnames and root SSH access. The existing
root authorized key is `chris@relic`; load that key into your SSH agent when
deploying from another workstation. All hive nodes belong to the `m75q` tag.
