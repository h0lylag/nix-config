#!/usr/bin/env bash
set -euo pipefail

patched_any=0
found_any=0

for app in discord discordptb; do
  config_dir="$HOME/.config/$app"
  if [[ ! -d "$config_dir" ]]; then
    continue
  fi

  shopt -s nullglob

  for krisp_node in $config_dir/*/modules/discord_krisp/discord_krisp.node; do
    found_any=1
    output=$(krisp-patch "$krisp_node" 2>&1) && patched_any=1

    if [[ "$output" =~ "already patched" ]]; then
      echo "Already patched: $krisp_node"
    elif [[ "$output" =~ "Found patch location" ]]; then
      echo "Patched: $krisp_node"
    else
      echo "Patch failed: $krisp_node"
      echo "  krisp-patcher output: $output"
    fi
  done

  shopt -u nullglob
done

if [[ "$found_any" -eq 0 ]]; then
  echo "No discord_krisp.node files found to patch."
elif [[ "$patched_any" -eq 1 ]]; then
  echo "All found discord_krisp.node files have been patched or were already patched."
else
  echo "No files were patched. (Possible errors encountered.)"
fi
