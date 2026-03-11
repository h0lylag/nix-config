#!/usr/bin/env bash
# ==============================================================================
# README: NixOS host bootstrapper (run from the NixOS live ISO)
# ==============================================================================
# Notes
# - Bootstrapper for my personal hosts
# - Opinionated: assumes this repo layout, flake outputs, and my defaults
# - Not a general-purpose installer
#
# What this script does
# - Destroys and provisions disks using hosts/<HOST>/disko.nix, mounts to /mnt
# - Stages this repo onto the target at /mnt/etc/nixos
# - Generates hardware-configuration.nix (without filesystems) and symlinks it
# - Installs the system using nixos-install --flake .#<HOST>
# - Fixes ownership of the staged repo/home
# - Prompts to set passwords for root and the target user
#
# Usage
#   sudo ./bootstrap.sh <HOST> [--yes]
#     <HOST>  Host folder under hosts/ and NixOS flake output name
#     --yes   Skip the confirmation prompt
#
# ==============================================================================

set -Eeuo pipefail
trap 'echo "ERROR: An unexpected error occurred. Installation failed." >&2' ERR

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <HOST> [--yes]" >&2
  exit 2
fi

HOST="$1"; shift
ASSUME_YES="no"
TARGET_USER="chris"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) ASSUME_YES="yes"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ────────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ────────────────────────────────────────────────────────────────────────────────

setup_zram() {
  if swapon --show | grep -q zram; then
    echo "[low-resource] zram already active, skipping."
    return
  fi
  local mem_kb
  mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  echo "[low-resource] Enabling zram swap (${mem_kb}KB, zstd, priority 32767)..."
  modprobe zram
  echo zstd > /sys/block/zram0/comp_algorithm
  echo "${mem_kb}K" > /sys/block/zram0/disksize
  mkswap /dev/zram0
  swapon /dev/zram0 -p 32767
  echo 200 > /proc/sys/vm/swappiness
  echo 10 > /proc/sys/vm/vfs_cache_pressure
  echo "[low-resource] zram swap enabled."
}

ensure_rwstore_space() {
  local avail
  avail=$(df --block-size=1K --output=avail /nix/.rw-store 2>/dev/null | tail -1 || echo 0)
  if [[ "$avail" -lt 524288 ]]; then  # under 512MB
    echo "[precheck] /nix/.rw-store has $((avail / 1024))MB free — remounting at 4G..."
    mount -o remount,size=4G /nix/.rw-store
    echo "[precheck] /nix/.rw-store remounted at 4G."
  fi
}

check_disk_space() {
  local disko_file="$1"
  local disk_device disk_size_bytes disk_size_gb
  # Best-effort: greps for device = "/dev/..." in disko.nix. May miss variables or
  # unusual formatting, but gracefully skips if the device can't be determined.
  disk_device=$(grep -E 'device\s*=' "$disko_file" | grep -Eo '"/dev/[^"]+' | head -1 | tr -d '"' || true)

  if [[ -z "$disk_device" || ! -b "$disk_device" ]]; then
    echo "[0/7] Disk space check skipped (device not detected from disko.nix)."
    return
  fi

  disk_size_bytes=$(lsblk --bytes --nodeps --output SIZE --noheadings "$disk_device" 2>/dev/null || echo 0)
  disk_size_gb=$((disk_size_bytes / 1024 / 1024 / 1024))
  echo "[0/7] Target disk: $disk_device (${disk_size_gb}GB)"

  if [[ "$disk_size_gb" -lt 15 ]]; then
    echo "ERROR: Target disk is only ${disk_size_gb}GB — minimum 15GB required." >&2
    exit 1
  elif [[ "$disk_size_gb" -lt 40 ]]; then
    echo "WARNING: Target disk is ${disk_size_gb}GB — NixOS with multiple generations may need 40GB+."
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# Resource Auto-detection (Prevent OOM on heavy builds)
# ────────────────────────────────────────────────────────────────────────────────

# Detect RAM in MB (more precise than GB for sub-4GB systems)
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_CORES=$(nproc)

# Default to 1 job if detection fails
INSTALL_MAX_JOBS=1

if [[ -n "$TOTAL_RAM_MB" && "$TOTAL_RAM_MB" -gt 0 ]]; then
  # Allocation Rule: ~4GB (4096MB) RAM per build job for heavy linking (Rust, C++, etc.)
  POSSIBLE_JOBS=$((TOTAL_RAM_MB / 4096))
  [[ "$POSSIBLE_JOBS" -lt 1 ]] && POSSIBLE_JOBS=1
  [[ "$POSSIBLE_JOBS" -gt "$TOTAL_CORES" ]] && POSSIBLE_JOBS="$TOTAL_CORES"
  INSTALL_MAX_JOBS="$POSSIBLE_JOBS"
fi

# Allow each job to use all cores (or use 0 for "auto"), as we limit concurrency
# via max-jobs. This allows single-threaded heavy jobs to finish faster if possible,
# or multithreaded jobs to use the CPU, but restricts HOW MANY run at once.
INSTALL_CORES=0

echo "Detected Resources: ${TOTAL_RAM_MB}MB RAM, ${TOTAL_CORES} Cores"
echo "Calculated Limits : max-jobs=${INSTALL_MAX_JOBS}, cores=${INSTALL_CORES}"

# ────────────────────────────────────────────────────────────────────────────────
# Low-Resource Mode
# ────────────────────────────────────────────────────────────────────────────────

LOW_RESOURCE="no"

if [[ "$TOTAL_RAM_MB" -le 4096 ]]; then
  LOW_RESOURCE="yes"
  echo "[low-resource] AUTO-ENABLED (${TOTAL_RAM_MB}MB RAM ≤ 4GB)."
elif [[ "$TOTAL_RAM_MB" -le 8192 ]]; then
  if [[ "${ASSUME_YES}" == "yes" ]]; then
    LOW_RESOURCE="yes"
    echo "[low-resource] AUTO-ENABLED in --yes mode (${TOTAL_RAM_MB}MB RAM, 4–8GB range)."
  else
    echo
    read -rp "System has ${TOTAL_RAM_MB}MB RAM (4–8GB). Enable low-resource mode? [y/N] " _lr_ans
    [[ "${_lr_ans:-}" =~ ^[Yy]$ ]] && LOW_RESOURCE="yes"
  fi
fi

if [[ "$LOW_RESOURCE" == "yes" ]]; then
  setup_zram
fi

# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n\n╔══════════════════════════════════════════════════════════════════╗"
echo -e   "║                          PRECHECKS                               ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root."; exit 1; }
command -v nix >/dev/null || { echo "nix missing on ISO."; exit 1; }
command -v git >/dev/null || { echo "git missing on ISO."; exit 1; }

ensure_rwstore_space

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_DIR="${SCRIPT_DIR}"
REPO_ROOT="$(cd "${HOSTS_DIR}/.." && pwd)"
HOST_DIR="${HOSTS_DIR}/${HOST}"

[[ -d "${HOST_DIR}" ]] || { echo "Host dir not found: ${HOST_DIR}" >&2; exit 1; }
[[ -f "${HOST_DIR}/disko.nix" ]] || { echo "Missing ${HOST_DIR}/disko.nix" >&2; exit 1; }

echo "[0/7] Repo root: ${REPO_ROOT}"
echo "[0/7] Host dir : ${HOST_DIR}"
echo "[0/7] Target user: ${TARGET_USER}"

check_disk_space "${HOST_DIR}/disko.nix"

# ────────────────────────────────────────────────────────────────────────────────
# 0) FORCE HOSTID (The "Foreign Pool" Fix)
# ────────────────────────────────────────────────────────────────────────────────
HOST_CONFIG="${HOST_DIR}/default.nix"
if [[ -f "$HOST_CONFIG" ]]; then
  DETECTED_HOSTID=$(grep -E 'hostId\s*=\s*"[0-9a-fA-F]{8}"' "$HOST_CONFIG" | sed -E 's/.*hostId\s*=\s*"([0-9a-fA-F]{8})".*/\1/' | head -n1 || true)

  if [[ -n "$DETECTED_HOSTID" ]]; then
    echo "[0/7] Applying hostId: ${DETECTED_HOSTID}"

    # Force removal of the read-only symlink/file first
    rm -f /etc/hostid

    if command -v zgenhostid >/dev/null; then
      zgenhostid "$DETECTED_HOSTID"
    else
      # Fallback binary write if tool is missing
      printf "$(echo "$DETECTED_HOSTID" | sed 's/../\\x&/g')" > /etc/hostid
    fi

    echo "      HostID applied: $(hostid)"
  else
    echo "[0/7] No hostId found in ${HOST_CONFIG} — ZFS import might warn later."
  fi
fi

if [[ "${ASSUME_YES}" != "yes" ]]; then
  echo
  echo "WARNING: This will (re)partition/format per ${HOST}/disko.nix and install NixOS."
  read -rp "Proceed? [y/N] " ans
  [[ "${ans:-}" =~ ^[Yy]$ ]] || exit 1
fi

# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n\n╔══════════════════════════════════════════════════════════════════╗"
echo -e   "║                           1) DISKO                               ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

echo "[1/7] Running disko (DESTRUCTIVE)…"
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko "${HOST_DIR}/disko.nix"
findmnt /mnt >/dev/null || { echo "/mnt not mounted — disko likely failed" >&2; exit 1; }

if [[ "$LOW_RESOURCE" == "yes" ]]; then
  echo "[low-resource] Running nix-collect-garbage to free /nix/.rw-store before install..."
  nix-collect-garbage
fi

# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n\n╔══════════════════════════════════════════════════════════════════╗"
echo -e   "║                        2) STAGE REPO                             ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

echo "[2/7] Staging repo to target filesystem…"
TARGET_HOME="/mnt/home/${TARGET_USER}"
REPO_PATH="/mnt/etc/nixos"
ETC_NIXOS="/mnt/etc/nixos"

mkdir -p "${TARGET_HOME}" "${ETC_NIXOS}"

if [[ -d "${REPO_PATH}/.git" ]]; then
  echo " - Repo already exists at ${REPO_PATH}"
else
  # Clone using HTTPS (no keys required for public/initial clone)
  git clone --recurse-submodules "https://github.com/h0lylag/nix-config.git" "${REPO_PATH}"

  # FIX: Switch remote to SSH so pushes work once keys are added
  git -C "${REPO_PATH}" remote set-url origin git@github.com:h0lylag/nix-config.git

  # FIX: Set your official identity (configure locally for this repo)
  git -C "${REPO_PATH}" config user.name 'h0lylag'
  git -C "${REPO_PATH}" config user.email 'h0lylag@gravemind.sh'
  # We don't need safe.directory if we own the repo, but we can set it if needed later.
  # For now, local config avoids the need for /root/.gitconfig creation via nixos-enter.
fi

# ────────────────────────────────────────────────────────────────────────────────
# [3/7] GENERATE HARDWARE-CONFIGURATION.NIX
echo "[3/7] Generating NEW hardware-configuration.nix..."
nixos-generate-config --root /mnt --no-filesystems

# Target location in your repo
TARGET_HW_CONFIG="${REPO_PATH}/hosts/${HOST}/hardware-configuration.nix"

# ALWAYS use the freshly generated one for the install
echo " - Overwriting repo hardware-config with freshly detected hardware data."
mv -f "${ETC_NIXOS}/hardware-configuration.nix" "${TARGET_HW_CONFIG}"

# Ensure the top-level symlink in /etc/nixos is correct
rm -f "${ETC_NIXOS}/configuration.nix"
# flake.nix is already at ${ETC_NIXOS}/flake.nix from the clone
ln -sfn "hosts/${HOST}/hardware-configuration.nix" "${ETC_NIXOS}/hardware-configuration.nix"

# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n\n╔══════════════════════════════════════════════════════════════════╗"
echo -e   "║                        4) INSTALL SYSTEM                         ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

INSTALL_OPTS=(
  --option max-jobs "$INSTALL_MAX_JOBS"
  --option cores "$INSTALL_CORES"
  --option extra-experimental-features "nix-command flakes"
)

if [[ "$LOW_RESOURCE" == "yes" ]]; then
  echo "[low-resource] Adding memory-saving install flags..."
  INSTALL_OPTS+=(
    --option sandbox false
    --option http-connections 1
    --option keep-derivations false
    --option keep-outputs false
  )
fi

echo "[4/7] Installing NixOS from flake: ${REPO_PATH}#${HOST}"
nixos-install --flake "${REPO_PATH}#${HOST}" --no-root-passwd "${INSTALL_OPTS[@]}"

# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n\n╔══════════════════════════════════════════════════════════════════╗"
echo -e   "║                       5) FIX OWNERSHIP                           ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

echo "[5/7] Chown repo and home to ${TARGET_USER} inside target"
if nixos-enter --root /mnt -- id -u "${TARGET_USER}" >/dev/null 2>&1; then
  PG="$(nixos-enter --root /mnt -- sh -c "id -gn ${TARGET_USER}")"
  nixos-enter --root /mnt -- chown -R "${TARGET_USER}:${PG}" "/etc/nixos"
  # ensure home itself is owned by user (in case we created it)
  nixos-enter --root /mnt -- chown "${TARGET_USER}:${PG}" "/home/${TARGET_USER}" || true
else
  echo "WARN: user '${TARGET_USER}' not found in target system — ensure users.users.${TARGET_USER} is defined."
fi

# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n\n╔══════════════════════════════════════════════════════════════════╗"
echo -e   "║                        6) SSH KEY SETUP                          ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

echo "[6/8] Setting up SSH keys for ${TARGET_USER}..."
SSH_DIR="/mnt/home/${TARGET_USER}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

KEY_FILE="${SSH_DIR}/id_ed25519"

if [[ -f "$KEY_FILE" ]]; then
  echo " - Key already exists at $KEY_FILE, skipping."
elif [[ "${ASSUME_YES}" == "yes" ]]; then
  echo " - Generating new ed25519 key (auto-mode)..."
  ssh-keygen -t ed25519 -N "" -f "$KEY_FILE" -C "${TARGET_USER}@${HOST}"
else
  echo "Do you want to paste an existing private key? [y/N] (N = generate new)"
  read -r -p "> " want_paste
  if [[ "$want_paste" =~ ^[Yy]$ ]]; then
    echo "Paste private key now. Press Ctrl+D (EOF) when finished:"
    cat > "$KEY_FILE"
    # Ensure it ends with newline if missing? cat handles EOF.
    echo "" >> "$KEY_FILE" # safety newline
    chmod 600 "$KEY_FILE"
    # Generate public key
    ssh-keygen -y -f "$KEY_FILE" > "${KEY_FILE}.pub"
  else
    echo " - Generating new ed25519 key..."
    ssh-keygen -t ed25519 -N "" -f "$KEY_FILE" -C "${TARGET_USER}@${HOST}"
  fi
fi

# Fix ownership
if nixos-enter --root /mnt -- id -u "${TARGET_USER}" >/dev/null 2>&1; then
    PG="$(nixos-enter --root /mnt -- sh -c "id -gn ${TARGET_USER}")"
    nixos-enter --root /mnt -- chown -R "${TARGET_USER}:${PG}" "/home/${TARGET_USER}/.ssh"
fi

# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n\n╔══════════════════════════════════════════════════════════════════╗"
echo -e   "║                         7) SET PASSWORDS                         ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

echo "[7/8] Setting passwords via nixos-enter (interactive with confirmation)"
echo

# ROOT (loop until success)
while true; do
  echo -e "\n── Setting ROOT password ──"
  if nixos-enter --root /mnt -- passwd root; then
    break
  else
    echo -e "\nPassword entry failed for root. Try again."
  fi
done

# USER (loop until success)
if nixos-enter --root /mnt -- getent passwd "${TARGET_USER}" >/dev/null 2>&1; then
  while true; do
    echo -e "\n── Setting USER password (${TARGET_USER}) ──"
    if nixos-enter --root /mnt -- passwd "${TARGET_USER}"; then
      break
    else
      echo -e "\nPassword entry failed for ${TARGET_USER}. Try again."
    fi
  done
else
  echo -e "\nWARN: user '${TARGET_USER}' not found in target system — ensure users.users.${TARGET_USER} is defined."
fi

# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n\n╔══════════════════════════════════════════════════════════════════╗"
echo -e   "║                              DONE                                ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

trap - ERR
echo "[8/8] Finished. You can now reboot."
