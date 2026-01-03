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
# - Stages this repo onto the target at /mnt/home/<user>/.nixos-config
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
# Resource Auto-detection (Prevent OOM on heavy builds)
# ────────────────────────────────────────────────────────────────────────────────

# Detect RAM in GB
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
# Detect Cores
TOTAL_CORES=$(nproc)

# Default to 1 job if detection fails
INSTALL_MAX_JOBS=1

if [[ -n "$TOTAL_RAM_GB" && "$TOTAL_RAM_GB" -gt 0 ]]; then
  # Allocation Rule: ~4GB RAM per build job for heavy linking (Rust, C++, etc.)
  POSSIBLE_JOBS=$((TOTAL_RAM_GB / 4))
  
  # Ensure at least 1 job
  if [[ "$POSSIBLE_JOBS" -lt 1 ]]; then POSSIBLE_JOBS=1; fi
  
  # Do not exceed physical core count
  if [[ "$POSSIBLE_JOBS" -gt "$TOTAL_CORES" ]]; then
    INSTALL_MAX_JOBS="$TOTAL_CORES"
  else
    INSTALL_MAX_JOBS="$POSSIBLE_JOBS"
  fi
fi

# Allow each job to use all cores (or use 0 for "auto"), as we limit concurrency
# via max-jobs. This allows single-threaded heavy jobs to finish faster if possible,
# or multithreaded jobs to use the CPU, but restricts HOW MANY run at once.
INSTALL_CORES=0

echo "Detected Resources: ${TOTAL_RAM_GB} GB RAM, ${TOTAL_CORES} Cores"
echo "Calculated Limits : max-jobs=${INSTALL_MAX_JOBS}, cores=${INSTALL_CORES}"


# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n\n╔══════════════════════════════════════════════════════════════════╗"
echo -e   "║                          PRECHECKS                               ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root."; exit 1; }
command -v nix >/dev/null || { echo "nix missing on ISO."; exit 1; }
command -v git >/dev/null || { echo "git missing on ISO."; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_DIR="${SCRIPT_DIR}"
REPO_ROOT="$(cd "${HOSTS_DIR}/.." && pwd)"
HOST_DIR="${HOSTS_DIR}/${HOST}"

[[ -d "${HOST_DIR}" ]] || { echo "Host dir not found: ${HOST_DIR}" >&2; exit 1; }
[[ -f "${HOST_DIR}/disko.nix" ]] || { echo "Missing ${HOST_DIR}/disko.nix" >&2; exit 1; }

echo "[0/7] Repo root: ${REPO_ROOT}"
echo "[0/7] Host dir : ${HOST_DIR}"
echo "[0/7] Target user: ${TARGET_USER}"

# ────────────────────────────────────────────────────────────────────────────────
# 0) FORCE HOSTID (The "Foreign Pool" Fix)
# ────────────────────────────────────────────────────────────────────────────────
HOST_CONFIG="${HOST_DIR}/default.nix"
if [[ -f "$HOST_CONFIG" ]]; then
  DETECTED_HOSTID=$(grep -E 'hostId\s*=\s*"[0-9a-fA-F]{8}"' "$HOST_CONFIG" | sed -E 's/.*hostId\s*=\s*"([0-9a-fA-F]{8})".*/\1/' | head -n1)
  
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
nix run github:nix-community/disko -- --mode disko "${HOST_DIR}/disko.nix"
findmnt /mnt >/dev/null || { echo "/mnt not mounted — disko likely failed" >&2; exit 1; }

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
  # Ensure dir is empty for git clone by removing empty dir if needed, or clone into .
  # safely we can just clone into it since we just made it.
  git clone --recurse-submodules "${REPO_ROOT}" "${REPO_PATH}"
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

echo "[4/7] Installing NixOS from flake: ${REPO_PATH}#${HOST}"
# To increase download buffer during install, prefix this line with:
# NIX_CONFIG=$'download-buffer-size = 256M\nexperimental-features = nix-command flakes' \
nixos-install --flake "${REPO_PATH}#${HOST}" --no-root-passwd \
  --option max-jobs "$INSTALL_MAX_JOBS" \
  --option cores "$INSTALL_CORES"

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
echo -e   "║                         6) SET PASSWORDS                         ║"
echo -e   "╚══════════════════════════════════════════════════════════════════╝\n"

echo "[6/7] Setting passwords via nixos-enter (interactive with confirmation)"
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
echo "[7/7] Finished. You can now reboot."
