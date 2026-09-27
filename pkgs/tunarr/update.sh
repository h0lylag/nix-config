#!/usr/bin/env bash
set -euo pipefail

# Run the package's updateScript from the flake root, regardless of the caller's cwd.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."

exec nix-update --flake --use-update-script tunarr
