#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/nix-update.sh PACKAGE[.SUBPACKAGE] [OPTIONS...]

Run nix-update on a pkgs/ recipe. Options are forwarded to nix-update
(see PACKAGE --help). A package's passthru.updateScript is used when defined,
unless --no-update-script or an option such as --version is given.

Examples:
  scripts/nix-update.sh tunarr
  scripts/nix-update.sh eve-preview-manager --build
  scripts/nix-update.sh tunarr --version=2026.9.1
EOF
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi
if (( $# == 0 )); then
  usage >&2
  exit 2
fi

package=$1
shift
if [[ ! $package =~ ^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*$ ]]; then
  printf 'Invalid package attribute: %s\n' "$package" >&2
  exit 2
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
recipe="pkgs/${package%%.*}/package.nix"
if [[ ! -f $recipe ]]; then
  printf 'No local package recipe: %s\n' "$recipe" >&2
  exit 2
fi

if ! command -v nix-update >/dev/null 2>&1; then
  printf 'nix-update is required but was not found on PATH.\n' >&2
  exit 127
fi

attribute="legacyPackages.x86_64-linux.$package"

# nix-update stops after running an update script, so these options would be
# ignored there; they select its built-in updater instead.
use_update_script=1
args=()
for arg in "$@"; do
  case $arg in
    --no-update-script)
      use_update_script=0
      continue
      ;;
    -h | --help | -u | --use-update-script | --version* | -vr | \
      --use-github-releases | --github-releases-limit* | -s | --subpackage* | \
      --src-only | --no-src | --override-filename* | --custom-dep* | \
      --generate-lockfile | --lockfile-metadata-path*)
      use_update_script=0
      ;;
  esac
  args+=("$arg")
done

if (( use_update_script )) &&
  [[ $(nix --extra-experimental-features 'nix-command flakes' eval --json \
    ".#$attribute" --apply 'p: p ? updateScript' 2>/dev/null) == true ]]; then
  args=(--use-update-script "${args[@]}")
fi

status=0
nix-update --flake "$attribute" "${args[@]}" || status=$?

# nix-update 1.16 builds the update script without --no-link; drop that link.
if [[ -L result && $(readlink result) == /nix/store/*-updateScript ]]; then
  rm -- result
fi
exit "$status"
