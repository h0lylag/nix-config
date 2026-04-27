#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_REPO="${SOURCE_REPO:-/home/chris/scripts/public-contracts}"
NIX_REPO="${NIX_REPO:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)}"
PACKAGE_FILE="${PACKAGE_FILE:-$SCRIPT_DIR/package.nix}"
PUSH_CHANGES=1
ALLOW_DIRTY=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: bump-nix-pin.sh [options]

Update the local package.nix next to this script to the current eve-public-contracts HEAD,
commit the change in the nix-config repo, and optionally push it.

Options:
  --no-push      Commit locally but do not push.
  --push         Push after committing (default).
  --allow-dirty  Allow running even if package.nix already has uncommitted changes.
  --dry-run      Print what would happen without changing anything.
  -h, --help     Show this help text.

Environment overrides:
  SOURCE_REPO    Defaults to the current working directory
  NIX_REPO       Defaults to the git repo containing this script
  PACKAGE_FILE   Defaults to the package.nix next to this script
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-push)
      PUSH_CHANGES=0
      ;;
    --push)
      PUSH_CHANGES=1
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd git
require_cmd perl

if [[ ! -d "$SOURCE_REPO/.git" ]]; then
  echo "Source repo does not look like a git checkout: $SOURCE_REPO" >&2
  exit 1
fi

src_root="$(git -C "$SOURCE_REPO" rev-parse --show-toplevel)"
nix_root="$(git -C "$NIX_REPO" rev-parse --show-toplevel)"
if [[ "$src_root" == "$nix_root" ]]; then
  echo "SOURCE_REPO and NIX_REPO resolve to the same repository ($src_root). Set SOURCE_REPO explicitly." >&2
  exit 1
fi

if [[ -z "$NIX_REPO" ]] || [[ ! -d "$NIX_REPO/.git" ]]; then
  echo "Nix repo does not look like a git checkout: $NIX_REPO" >&2
  exit 1
fi

if [[ ! -f "$PACKAGE_FILE" ]]; then
  echo "Package file not found: $PACKAGE_FILE" >&2
  exit 1
fi

if [[ "$ALLOW_DIRTY" -ne 1 ]]; then
  if ! git -C "$NIX_REPO" diff --quiet -- "$PACKAGE_FILE" || ! git -C "$NIX_REPO" diff --cached --quiet -- "$PACKAGE_FILE"; then
    echo "$PACKAGE_FILE already has uncommitted changes. Commit or stash them first, or rerun with --allow-dirty." >&2
    exit 1
  fi
fi

new_rev="$(git -C "$SOURCE_REPO" rev-parse HEAD)"
new_date="$(git -C "$SOURCE_REPO" log -1 --date=format:%F --format='%cd')"
new_subject="$(git -C "$SOURCE_REPO" log -1 --format='%s')"

current_rev="$(perl -nE 'say $1 if /rev = \"([0-9a-f]{40})\";/' "$PACKAGE_FILE" | head -n1)"
current_version="$(perl -nE 'say $1 if /version = \"(unstable-[0-9]{4}-[0-9]{2}-[0-9]{2})\";/;' "$PACKAGE_FILE" | head -n1)"
new_version="unstable-$new_date"

if [[ -z "$current_rev" ]] || [[ -z "$current_version" ]]; then
  echo "Could not find the current rev/version in $PACKAGE_FILE" >&2
  exit 1
fi

if [[ "$current_rev" == "$new_rev" ]] && [[ "$current_version" == "$new_version" ]]; then
  echo "Already up to date:"
  echo "  rev: $new_rev"
  echo "  version: $new_version"
  exit 0
fi

echo "eve-public-contracts bump"
echo "  source repo:   $SOURCE_REPO"
echo "  nix repo:      $NIX_REPO"
echo "  package file:  $PACKAGE_FILE"
echo "  old rev:       $current_rev"
echo "  new rev:       $new_rev"
echo "  old version:   $current_version"
echo "  new version:   $new_version"
echo "  source commit: $new_subject"

if [[ "$DRY_RUN" -eq 1 ]]; then
  exit 0
fi

perl -0pi -e \
  "s/version = \"\Q$current_version\E\";/version = \"$new_version\";/; s/rev = \"\Q$current_rev\E\";/rev = \"$new_rev\";/" \
  "$PACKAGE_FILE"

git -C "$NIX_REPO" add "$PACKAGE_FILE"
git -C "$NIX_REPO" commit -m "eve-public-contracts: bump to ${new_rev:0:12}"

if [[ "$PUSH_CHANGES" -eq 1 ]]; then
  git -C "$NIX_REPO" push
fi

echo "Done."
