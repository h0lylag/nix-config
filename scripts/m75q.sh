#!/usr/bin/env bash
set -euo pipefail

script_name=${0##*/}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
mac_file=${M75Q_MAC_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/m75q/mac-addresses}
broadcast=${M75Q_BROADCAST:-10.1.1.255}
rustdesk_delay=${M75Q_RUSTDESK_DELAY:-0.2}
rustdesk_targets=${M75Q_RUSTDESK_TARGETS:-}

# Edit one row per host: name, LAN IPv4, Wake-on-LAN MAC.
host_records=(
  '001-shamed-instrument 10.1.1.31 e0:be:03:18:ec:bc'
  '007-contrite-witness 10.1.1.32 e0:be:03:18:ec:5d'
  '049-abject-testament 10.1.1.33 6c:4b:90:e5:56:ae'
  '2401-penitent-tangent 10.1.1.34 e0:be:03:16:1f:39'
  '16807-abashed-eulogy 10.1.1.35 6c:4b:90:e5:4a:ae'
  '117649-despondent-pyre 10.1.1.36 6c:4b:90:e5:b6:9f'
)

hosts=()
declare -A host_ip=() host_mac=()

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
  M75Q_RUSTDESK_DELAY    Seconds between launches (default: $rustdesk_delay)

MAC map format:
  001-shamed-instrument aa:bb:cc:dd:ee:ff
EOF
}

die() {
  echo "$script_name: $*" >&2
  exit 1
}

init_hosts() {
  local row host ip mac extra
  for row in "${host_records[@]}"; do
    read -r host ip mac extra <<< "$row"
    [[ -n "$host" && -n "$ip" && -n "$mac" && -z "$extra" ]] ||
      die "invalid host row: $row"
    [[ -z ${host_ip[$host]+x} ]] || die "duplicate host: $host"
    hosts+=("$host")
    host_ip[$host]=$ip
    host_mac[$host]=$mac
  done
}

load_mac_file() {
  [[ -e "$mac_file" ]] || return 0
  [[ -r "$mac_file" ]] || die "cannot read MAC map: $mac_file"

  local host mac ignored
  while read -r host mac ignored || [[ -n "${host:-}" ]]; do
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

  command -v wol >/dev/null || die "wol is required for wake"
  local repeat
  for ((repeat = 0; repeat < 3; repeat++)); do
    wol -i "$broadcast" -p 9 "${macs[@]}" >/dev/null
    ((repeat == 2)) || sleep 0.1
  done
  for mac in "${macs[@]}"; do
    printf 'sent 3 Wake-on-LAN packets to %s via %s\n' "$mac" "$broadcast"
  done
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

  local -a targets=()
  local host index

  if [[ -n "$rustdesk_targets" ]]; then
    read -r -a targets <<< "$rustdesk_targets"
  else
    for host in "${hosts[@]}"; do
      targets+=("$(tailscale_ip "$host")")
    done
  fi

  ((${#targets[@]} == ${#hosts[@]})) ||
    die "M75Q_RUSTDESK_TARGETS must contain ${#hosts[@]} targets"
  [[ "$rustdesk_delay" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] ||
    die "M75Q_RUSTDESK_DELAY must be a nonnegative number"

  for index in "${!hosts[@]}"; do
    host=${hosts[$index]}
    printf 'launching RustDesk for %s (%s)\n' "$host" "${targets[$index]}"
    rustdesk --connect "${targets[$index]}" &
    if ((index + 1 < ${#hosts[@]})); then
      sleep "$rustdesk_delay"
    fi
  done
}

[[ $# -gt 0 ]] || {
  usage
  exit 2
}

init_hosts
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
