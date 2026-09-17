#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/check-config.sh [BASE_REF]

Check formatting of changed and untracked Nix files relative to BASE_REF (HEAD
by default), evaluate the flake without building, and evaluate every host and
its nested NixOS containers, and check the Colmena hive against the host outputs.
Requires bash, git, nix, nixfmt, jq, and coreutils.

Progress goes to stderr; stdout contains a JSON derivation snapshot on success.
For structural changes, save snapshots before and after and compare with diff:
  scripts/check-config.sh > /tmp/before.json
  # Make changes, then:
  scripts/check-config.sh > /tmp/after.json
  diff -u /tmp/before.json /tmp/after.json

New Nix files imported by the flake must be visible to Git (for example, through
git add --intent-to-add). This script does not stage files or activate systems.
EOF
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi
if (( $# > 1 )); then
  usage >&2
  exit 2
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
base_ref=${1:-HEAD}
git rev-parse --verify "${base_ref}^{commit}" >/dev/null
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT

git diff --name-only -z --diff-filter=ACMR "$base_ref" -- '*.nix' > "$scratch/changed"
git ls-files --others --exclude-standard -z -- '*.nix' >> "$scratch/changed"
sort -zu "$scratch/changed" > "$scratch/unique"
while IFS= read -r -d '' file; do
  if [[ -f $file ]]; then
    printf 'Checking formatting: %s\n' "$file" >&2
    nixfmt --check "./$file" >&2
  fi
done < "$scratch/unique"

printf 'Evaluating all flake configurations...\n' >&2
nix flake check --no-build --no-write-lock-file >&2

printf 'Evaluating host and nested container derivations...\n' >&2
nix eval --option eval-cache false --no-write-lock-file --json \
  .#nixosConfigurations --apply '
    systems: builtins.mapAttrs (_: system: {
      host = system.config.system.build.toplevel.drvPath;
      containers = builtins.mapAttrs
        (_: container: container.config.system.build.toplevel.drvPath)
        system.config.containers;
    }) systems
  ' > "$scratch/snapshot.json"

printf 'Evaluating Colmena membership, deployment settings, and derivations...\n' >&2
nix eval --option eval-cache false --no-write-lock-file --json \
  .#colmenaHive --apply '
    hive:
    assert builtins.attrNames hive.nodes == [
      "001-shamed-instrument"
      "007-contrite-witness"
      "049-abject-testament"
      "117649-despondent-pyre"
      "16807-abashed-eulogy"
      "2401-penitent-tangent"
    ];
    builtins.mapAttrs (name: node:
      assert !node.config.deployment.buildOnTarget;
      assert node.config.deployment.targetHost == name;
      assert node.config.deployment.targetUser == "root";
      assert builtins.elem "m75q" node.config.deployment.tags;
      assert node.config.services.tailscale.enable;
      node.config.system.build.toplevel.drvPath
    ) hive.nodes
  ' > "$scratch/hive.json"
if ! jq -e --slurpfile hive "$scratch/hive.json" '
  . as $snapshot |
  all($hive[0] | to_entries[]; .value == $snapshot[.key].host)
' "$scratch/snapshot.json" >/dev/null; then
  printf 'Colmena system derivations differ from the corresponding Den host outputs.\n' >&2
  exit 1
fi

cat "$scratch/snapshot.json"
printf '\n'
