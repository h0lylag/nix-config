#!/usr/bin/env bash
set -euo pipefail

script_name=${0##*/}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
mac_file=${M75Q_MAC_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/m75q/mac-addresses}
broadcast=${M75Q_BROADCAST:-10.1.1.255}

hosts=(
  001-shamed-instrument
  007-contrite-witness
  049-abject-testament
  2401-penitent-tangent
  16807-abashed-eulogy
  117649-despondent-pyre
)

declare -A host_ip=(
  [001-shamed-instrument]=10.1.1.31
  [007-contrite-witness]=10.1.1.32
  [049-abject-testament]=10.1.1.33
  [2401-penitent-tangent]=10.1.1.34
  [16807-abashed-eulogy]=10.1.1.35
  [117649-despondent-pyre]=10.1.1.36
)
declare -A host_mac=(
  [001-shamed-instrument]=e0:be:03:18:ec:bc
  [007-contrite-witness]=e0:be:03:18:ec:5d
  [049-abject-testament]=6c:4b:90:e5:56:ae
  [2401-penitent-tangent]=e0:be:03:16:1f:39
  [16807-abashed-eulogy]=6c:4b:90:e5:4a:ae
  [117649-despondent-pyre]=6c:4b:90:e5:b6:9f
)

usage() {
  cat <<EOF
Usage: $script_name <command> [args...]

Commands:
  wake       Send Wake-on-LAN packets to all M75q hosts
  discover   Show neighbor MACs, falling back to configured MACs
  apply      Run: colmena apply --on @m75q [args...]
  reboot     Run: colmena exec --verbose --on @m75q -- reboot
  poweroff   Run: colmena exec --verbose --on @m75q -- poweroff
  rustdesk   Launch RustDesk connections in host order
  exec       Run a command on all M75q hosts

Wake-on-LAN settings:
  M75Q_BROADCAST   Broadcast address (default: $broadcast)
  M75Q_MAC_FILE    Optional MAC map override (default: $mac_file)

RustDesk settings:
  M75Q_RUSTDESK_TARGETS  Space-separated targets in host order (default: Tailscale IPv4)
  M75Q_RUSTDESK_DELAY    Seconds between launches (default: 0.2)

MAC map format:
  001-shamed-instrument aa:bb:cc:dd:ee:ff
EOF
}

die() {
  echo "$script_name: $*" >&2
  exit 1
}

load_mac_file() {
  [[ -r "$mac_file" ]] || return 0

  local host mac ignored
  while read -r host mac ignored; do
    [[ -z "${host:-}" || "$host" == \#* ]] && continue
    [[ -n "${host_ip[$host]+x}" ]] && host_mac[$host]=$mac
  done < "$mac_file"
}

neighbor_mac() {
  local host=$1
  ip neigh show "${host_ip[$host]}" 2>/dev/null |
    awk '$4 == "lladdr" { print $5; exit }' || :
}

valid_mac() {
  [[ "$1" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]
}

discover() {
  load_mac_file

  local host mac
  for host in "${hosts[@]}"; do
    mac=$(neighbor_mac "$host")
    [[ -n "$mac" ]] || mac=${host_mac[$host]-}
    if valid_mac "$mac"; then
      printf '%s %s\n' "$host" "$mac"
    else
      printf '# %s (%s): no MAC in neighbor table\n' "$host" "${host_ip[$host]}"
    fi
  done
}

wake() {
  load_mac_file

  local host mac
  local -a macs=()
  local -a missing=()
  for host in "${hosts[@]}"; do
    mac=${host_mac[$host]-}
    [[ -n "$mac" ]] || mac=$(neighbor_mac "$host")
    mac=${mac//-/:}
    if valid_mac "$mac"; then
      macs+=("$mac")
    else
      missing+=("$host (${host_ip[$host]})")
    fi
  done

  if ((${#missing[@]})); then
    printf 'Missing MAC address for %s.\n' "${missing[*]}" >&2
    printf 'Keep each host online, run `%s discover`, and save the output to %s.\n' "$script_name" "$mac_file" >&2
    return 1
  fi

  command -v python3 >/dev/null || die "python3 is required for wake"
  python3 - "$broadcast" "${macs[@]}" <<'PY'
import socket
import sys
import time

broadcast, *macs = sys.argv[1:]
packets = [
    (mac, b"\xff" * 6 + bytes.fromhex(mac.replace(":", "")) * 16)
    for mac in macs
]
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    for repeat in range(3):
        for _, packet in packets:
            sock.sendto(packet, (broadcast, 9))
        if repeat < 2:
            time.sleep(0.1)
    for mac, _ in packets:
        print(f"sent 3 Wake-on-LAN packets to {mac} via {broadcast}")
PY
}

tailscale_ip() {
  local host=$1 ip
  command -v getent >/dev/null || die "getent is required to resolve Tailscale hosts"
  ip=$(getent ahostsv4 "$host" 2>/dev/null |
    awk '$1 ~ /^100\./ { print $1; exit }')
  [[ -n "$ip" ]] ||
    die "could not resolve a Tailscale IPv4 address for $host; set M75Q_RUSTDESK_TARGETS"
  printf '%s\n' "$ip"
}

launch_rustdesk() {
  command -v rustdesk >/dev/null || die "rustdesk is required for this command"

  local delay=${M75Q_RUSTDESK_DELAY:-0.2}
  local targets_value=${M75Q_RUSTDESK_TARGETS:-}
  local resolve_targets=1
  local -a targets=()
  local host target

  if [[ -n "$targets_value" ]]; then
    read -r -a targets <<< "$targets_value"
    resolve_targets=0
  else
    for host in "${hosts[@]}"; do
      targets+=("$host")
    done
  fi

  ((${#targets[@]} == ${#hosts[@]})) ||
    die "M75Q_RUSTDESK_TARGETS must contain ${#hosts[@]} targets"

  local index
  for index in "${!hosts[@]}"; do
    host=${hosts[$index]}
    target=${targets[$index]}
    if ((resolve_targets)); then
      target=$(tailscale_ip "$target")
    fi
    printf 'launching RustDesk for %s (%s)\n' "$host" "$target"
    rustdesk --connect "$target" &
    if ((index + 1 < ${#hosts[@]})); then
      sleep "$delay"
    fi
  done
}

[[ $# -gt 0 ]] || {
  usage
  exit 2
}

cd "$repo_root"
command=$1
shift

case "$command" in
  wake|power-on)
    (($# == 0)) || die "wake does not accept arguments"
    wake
    ;;
  discover)
    (($# == 0)) || die "discover does not accept arguments"
    discover
    ;;
  apply)
    colmena apply --on @m75q "$@"
    ;;
  reboot)
    (($# == 0)) || die "reboot does not accept arguments"
    colmena exec --verbose --on @m75q -- reboot
    ;;
  poweroff)
    (($# == 0)) || die "poweroff does not accept arguments"
    colmena exec --verbose --on @m75q -- poweroff
    ;;
  rustdesk|connect)
    (($# == 0)) || die "rustdesk does not accept arguments"
    launch_rustdesk
    ;;
  exec)
    (($# > 0)) || die "exec needs a command"
    colmena exec --verbose --on @m75q -- "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
