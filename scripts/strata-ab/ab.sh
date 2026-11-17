#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/strata-ab/ab.sh [OPTIONS] ARM...

A/B arms for relic's strata.service. Each arm restarts the service with a runtime
drop-in (/run/systemd/system/strata.service.d, gone on reboot) and temporary
sysctls, runs bench.py against it, and compare.py prints the table at the end.
Everything is restored on exit: no drop-in, strata stopped, nr_hugepages 0, the
original compaction_proactiveness and Strata's saved launch choices.

An arm is parts joined by '+', for example base, s1, s1+huge+thpoff+decode:
  base         the deployed unit as it is
  s1           LimitMEMLOCK=infinity, MemorySwapMax=0, O_DIRECT arena load, exact
               long-prompt scorer (what den/aspects/llm/strata.nix sets)
  huge         reserve 2 MiB hugetlb pages for the expert arena (HUGE_PAGES, 24000)
  nohuge       release the pool, for comparing against a config that reserves it
  thpoff       start strata under Maya's PR_SET_THP_DISABLE wrapper
  calm         vm.compaction_proactiveness=0
  decode       STRATA_EXP_MODE=8 STRATA_HC_Q8=1 (rounding changes)
  prefill      the gfx11 matrix-core prompt set (rounding changes)
  rdna4        the bit-exact decode switches the engine sets by default on gfx12
  NAME=VALUE   another engine environment variable
  --FLAG=VALUE an engine argument, passed as `strata launch --set FLAG=VALUE`

Options:
  --stop-maya        stop maya.service if it runs (starting strata stops it anyway)
  --rounds N         decode rounds per arm (3)
  --prefill SIZES    fresh-prompt sizes in tokens, comma list or '' (16000,64000)
  --sweep ARM        afterwards, run the per-request arms on ARM's engine: six
                     rounds over SWEEP_KINDS (code,explain,json,refactor), so
                     each arm answers every subject once
  --tune JSON        a per-request arm for --sweep, repeatable (default: PCIe
                     share 0.55 / 0.7 / 0.85 / 1.0 and aux_cpus 1)

Results go to $OUT (default ~/.local/state/strata-ab/<time>). sudo runs only
systemctl, sysctl and file writes under /run, /proc/sys and Strata's state; set
SUDO_ASKPASS to run unattended. Compare several runs with
  scripts/strata-ab/compare.py DIR...
EOF
}

here=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-${XDG_STATE_HOME:-$HOME/.local/state}/strata-ab/$(date +%Y%m%dT%H%M%S)}
URL=http://127.0.0.1:8081
DROPIN_DIR=/run/systemd/system/strata.service.d
DROPIN=$DROPIN_DIR/50-ab.conf
LAUNCH=/var/lib/strata/.local/state/strata/launch
LOG=$LAUNCH/iq3_s-256k.engine.log
CHOICES=$LAUNCH/iq3_s-256k.choices.json
HUGE_PAGES=${HUGE_PAGES:-24000}
SUDO=(sudo)
[[ -n ${SUDO_ASKPASS:-} ]] && SUDO=(sudo -A)

stop_maya=0 rounds=3 prefill=16000,64000 sweep="" tunes=() arms=()
while (($#)); do
  case $1 in
    -h | --help) usage; exit 0 ;;
    --stop-maya) stop_maya=1 ;;
    --rounds) rounds=$2; shift ;;
    --prefill) prefill=$2; shift ;;
    --sweep) sweep=$2; shift ;;
    --tune) tunes+=("$2"); shift ;;
    --*=* | [!-]*) arms+=("$1") ;;
    *) echo "unknown option $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
((${#arms[@]})) || [[ -n $sweep ]] || { usage >&2; exit 2; }
((${#tunes[@]})) || tunes=('{}' '{"pcie_frac": 0.7}' '{"pcie_frac": 0.85}' '{"pcie_frac": 1.0}' '{"aux_cpus": 1}')

if systemctl is-active -q maya; then
  ((stop_maya)) || { echo "maya is active; starting strata would stop it. Re-run with --stop-maya." >&2; exit 1; }
  "${SUDO[@]}" systemctl stop maya
fi

exec_start=$(systemctl cat strata | sed -n 's/^ExecStart=//p' | tail -1)
thp_off=$(systemctl cat maya | sed -n 's/^ExecStart=\([^ ]*thp-off\) .*/\1/p' | head -1)
strata_share=$(systemctl show strata -p Environment --value | tr ' ' '\n' |
  sed -n 's|^STRATA_HIPBLASLT_TUNING=\(.*\)/tools/hip/.*|\1|p')
proactive0=$(cat /proc/sys/vm/compaction_proactiveness)
mkdir -p "$OUT"
# `strata launch --set` saves its values in the choices file and later launches keep them.
choices_bak=$OUT/.choices.json
"${SUDO[@]}" cat "$CHOICES" >"$choices_bak"

declare -A PARTS=(
  [s1]="STRATA_UNBUFFERED_LOAD=1 STRATA_SCORES_THREAD=1"
  [decode]="STRATA_EXP_MODE=8 STRATA_HC_Q8=1"
  [prefill]="STRATA_PF_FUSED=1 STRATA_HIP_WMMA=1 STRATA_GDN_CHUNKED=1 STRATA_PF_F16=1 STRATA_PA_FAST=1 STRATA_HC_UPMIX=1 STRATA_PF_GEMM=1 STRATA_PF_PAD=1"
  [rdna4]="STRATA_ATTN_LANECELL=1 STRATA_ATTN_MERGE_V2=1 STRATA_TSUM=1 STRATA_EXPDEC=1 STRATA_SMALL_UNR=3 STRATA_GR_Q32_G=2 STRATA_GR_Q8_PFS=1"
)

sysctl_w() { printf '%s\n' "$2" | "${SUDO[@]}" tee "/proc/sys/vm/$1" >/dev/null; }

restore() {
  "${SUDO[@]}" rm -f "$DROPIN"
  "${SUDO[@]}" systemctl daemon-reload
  sysctl_w compaction_proactiveness "$proactive0"
  "${SUDO[@]}" tee "$CHOICES" <"$choices_bak" >/dev/null
}

cleanup() {
  "${SUDO[@]}" systemctl stop strata || true
  restore
  sysctl_w nr_hugepages 0
  echo "Restored: no drop-in, strata stopped, nr_hugepages 0, compaction_proactiveness $proactive0, launch choices. Results: $OUT"
}
trap cleanup EXIT

start_arm() {
  local arm=$1 part text="" envs=() sets=() huge=0 thpoff=0 calm=0 props=0 e
  IFS=+ read -ra parts <<<"$arm"
  for part in "${parts[@]}"; do
    case $part in
      base) ;;
      s1) props=1; read -ra e <<<"${PARTS[s1]}"; envs+=("${e[@]}") ;;
      decode | prefill | rdna4) read -ra e <<<"${PARTS[$part]}"; envs+=("${e[@]}") ;;
      # The engine's RAM check does not count the hugetlb pool, so without these it reads the
      # experts from the files instead of mapping the pool.
      huge) huge=1; envs+=(STRATA_ARENA_RAM_FALLBACK=0 STRATA_ARENA_RAM_WAIT_S=0) ;;
      nohuge) huge=0 ;;
      thpoff) thpoff=1 ;;
      calm) calm=1 ;;
      --*=*) sets+=("${part#--}") ;;
      *=*) envs+=("$part") ;;
      *) echo "unknown arm part $part" >&2; exit 2 ;;
    esac
  done

  "${SUDO[@]}" systemctl stop strata || true
  restore
  sysctl_w nr_hugepages 0
  if ((calm)); then sysctl_w compaction_proactiveness 0; fi
  if ((huge)); then
    # MAP_HUGETLB is all or nothing: free and compact memory first, then check the pool.
    sync
    sysctl_w drop_caches 3
    sysctl_w compact_memory 1
    sysctl_w nr_hugepages "$HUGE_PAGES"
    echo "=== $arm: hugetlb pool $(cat /proc/sys/vm/nr_hugepages) of $HUGE_PAGES pages"
  fi

  if ((props || ${#envs[@]} || ${#sets[@]} || thpoff)); then
    local cmd=$exec_start
    for s in "${sets[@]}"; do cmd+=" --set '$s'"; done
    ((thpoff)) && { [[ -n $thp_off ]] || { echo "no thp-off wrapper in maya.service" >&2; exit 2; }; cmd="$thp_off $cmd"; }
    text="[Service]"$'\n'
    if ((props)); then text+="LimitMEMLOCK=infinity"$'\n'"MemorySwapMax=0"$'\n'; fi
    for e in "${envs[@]}"; do text+="Environment=$e"$'\n'; done
    if [[ $cmd != "$exec_start" ]]; then text+="ExecStart="$'\n'"ExecStart=$cmd"$'\n'; fi
    "${SUDO[@]}" mkdir -p "$DROPIN_DIR"
    printf '%s' "$text" | "${SUDO[@]}" tee "$DROPIN" >/dev/null
    "${SUDO[@]}" systemctl daemon-reload
  fi

  echo "=== $arm: starting strata"
  local t0=$SECONDS
  "${SUDO[@]}" systemctl start strata || { echo "=== $arm: INVALID, strata did not start" | tee "$OUT/$arm.invalid"; return 1; }
  local up=0
  for _ in $(seq 120); do curl -sf -m 2 "$URL/v1/models" >/dev/null && { up=1; break; }; sleep 2; done
  ((up)) || { echo "=== $arm: INVALID, the server never answered" | tee "$OUT/$arm.invalid"; return 1; }
  echo "=== $arm: serving after $((SECONDS - t0)) s"
  # This start's lines: memory, huge pages, the PLE lock, the expert cache and the switches.
  "${SUDO[@]}" cat "$LOG" | awk '/engine started/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' |
    grep -E 'engine started|expert arena|experts via|PLE|ple-io|conversation cache sized|expert cache [0-9]+ slots|VRAM free with|loaded [0-9.]+ GiB at|8-bit|matrix' \
      >"$OUT/$arm.startup.txt" || true
  sed 's/^/    /' "$OUT/$arm.startup.txt"
  # An arm the engine quietly ran differently measures something else: refuse it.
  if [[ $arm != *mmap* ]] && grep -q 'experts via mmap' "$OUT/$arm.startup.txt"; then
    echo "=== $arm: INVALID, the experts are read from the files (no RAM arena)" | tee "$OUT/$arm.invalid"
    return 1
  fi
  if ((huge)) && ! grep -q 'hugetlb 2 MB pages' "$OUT/$arm.startup.txt"; then
    echo "=== $arm: INVALID, the arena is not on the hugetlb pool" | tee "$OUT/$arm.invalid"
    return 1
  fi
}

bench() { python3 -I "$here/bench.py" --url "$URL" --out "$OUT" --corpus "$strata_share/serve" --corpus "$strata_share/strata_control" "$@"; }

i=0
for arm in "${arms[@]}"; do
  i=$((i + 1))
  start_arm "$arm" || continue
  bench --label "$i-$arm" --rounds "$rounds" --prefill "$prefill" | tee "$OUT/$i-$arm.txt"
done

if [[ -n $sweep ]] && start_arm "$sweep"; then
  targs=()
  for t in "${tunes[@]}"; do targs+=(--tune "$t"); done
  # Six rounds: bench.py rotates the six subjects, so every arm reads each of them once.
  bench --label "sweep-$sweep" --rounds 6 --kinds "${SWEEP_KINDS:-code,explain,json,refactor}" \
    --prefill "" "${targs[@]}" | tee "$OUT/sweep-$sweep.txt"
fi

python3 -I "$here/compare.py" "$OUT" | tee "$OUT/summary.txt"
