#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/check-workarounds.sh

Report the status of each temporary workaround in workarounds.nix, evaluated
against the locked flake inputs:
  ready    the removal condition looks met; try removing the workaround
  manual   no evaluated probe; check the removal condition by hand
  waiting  the removal condition is not met yet
Fails if an entry lists a file that does not exist. Requires nix and jq.
EOF
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi
if (( $# > 0 )); then
  usage >&2
  exit 2
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
workarounds=$(nix eval --option eval-cache false --no-write-lock-file --json .#workarounds)

status=0
while IFS=$'\t' read -r name file; do
  if [[ ! -e $file ]]; then
    printf '%s lists a missing file: %s\n' "$name" "$file" >&2
    status=1
  fi
done < <(jq -r 'to_entries[] | .key as $name | .value.files[] | [$name, .] | @tsv' <<<"$workarounds")

printf 'Temporary workarounds (workarounds.nix):\n'
jq -r '
  (keys | map(length) | max) as $width
  | to_entries
  | map(.status = (
      if .value.ready == true then "ready"
      elif .value.ready == false then "waiting"
      else "manual" end))
  | sort_by([{ ready: 0, manual: 1, waiting: 2 }[.status], .key])
  | .[]
  | "  \(.status + " " * (8 - (.status | length))) \(.key + " " * ($width + 1 - (.key | length)))\(.value.removeWhen)"
' <<<"$workarounds"
exit "$status"
