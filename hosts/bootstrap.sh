#!/usr/bin/env bash
# hosts/bootstrap.sh — run from the NixOS live ISO
#
# Usage:
#   sudo ./bootstrap.sh <HOST> [--yes]
#
# Example:
#   sudo ./bootstrap.sh beavercreek --yes

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

# ╔══════════════════════════════════════════════════════════════════╗
# ║                          PRECHECKS                               ║
# ╚══════════════════════════════════════════════════════════════════╝
[[ "$(id -u)" -eq 0 ]] || { echo "Run as root."; exit 1; }
[[ -d /sys/firmware/efi/efivars ]] || { echo "System not booted in UEFI mode."; exit 1; }
command -v nix >/dev/null || { echo "nix missing on ISO."; exit 1; }
command -v git >/dev/null || { echo "git missing on ISO."; exit 1; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_DIR="${SCRIPT_DIR}"
REPO_ROOT="$(cd "${HOSTS_DIR}/.." && pwd)"
HOST_DIR="${HOSTS_DIR}/${HOST}"

[[ -d "${HOST_DIR}" ]] || { echo "Host dir not found: ${HOST_DIR}" >&2; exit 1; }
[[ -f "${HOST_DIR}/disko.nix" ]] || { echo "Missing ${HOST_DIR}/disko.nix" >&2; exit 1; }

echo "[0/6] Repo root: ${REPO_ROOT}"
echo "[0/6] Host dir : ${HOST_DIR}"
echo "[0/6] Target user: ${TARGET_USER}"

if [[ "${ASSUME_YES}" != "yes" ]]; then
  echo
  echo "WARNING: This will (re)partition/format per ${HOST}/disko.nix and install NixOS."
  read -rp "Proceed? [y/N] " ans
  [[ "${ans:-}" =~ ^[Yy]$ ]] || exit 1
fi

# ╔══════════════════════════════════════════════════════════════════╗
# ║                           1. DISKO                               ║
# ╚══════════════════════════════════════════════════════════════════╝
echo "[1/6] Running disko (DESTRUCTIVE)…"
nix run github:nix-community/disko -- --mode disko "${HOST_DIR}/disko.nix"
findmnt /mnt >/dev/null || { echo "/mnt not mounted — disko likely failed" >&2; exit 1; }

# ╔══════════════════════════════════════════════════════════════════╗
# ║                        2. STAGE REPO                             ║
# ╚══════════════════════════════════════════════════════════════════╝
echo "[2/6] Staging repo to target filesystem…"
TARGET_HOME="/mnt/home/${TARGET_USER}"
REPO_PATH="${TARGET_HOME}/.nixos-config"
ETC_NIXOS="/mnt/etc/nixos"

mkdir -p "${TARGET_HOME}" "${ETC_NIXOS}"

if [[ -d "${REPO_PATH}/.git" ]]; then
  echo " - Repo already exists at ${REPO_PATH}"
else
  git clone --recurse-submodules "${REPO_ROOT}" "${REPO_PATH}"
fi

# ╔══════════════════════════════════════════════════════════════════╗
# ║         3. GENERATE HARDWARE-CONFIGURATION.NIX                   ║
# ║                (NO FILESYSTEMS — DISKO OWNS FS)                  ║
# ╚══════════════════════════════════════════════════════════════════╝
echo "[3/6] Generating hardware-configuration.nix into repo (no filesystems)…"
nixos-generate-config --root /mnt --no-filesystems

if [[ -f "${ETC_NIXOS}/hardware-configuration.nix" ]]; then
  mv -f "${ETC_NIXOS}/hardware-configuration.nix" \
        "${REPO_PATH}/hosts/${HOST}/hardware-configuration.nix"
fi
rm -f "${ETC_NIXOS}/configuration.nix" "${ETC_NIXOS}/flake.nix"
ln -sfn "${REPO_PATH}/hosts/${HOST}/hardware-configuration.nix" \
        "${ETC_NIXOS}/hardware-configuration.nix"

# ╔══════════════════════════════════════════════════════════════════╗
# ║                        4. INSTALL SYSTEM                         ║
# ╚══════════════════════════════════════════════════════════════════╝
echo "[4/6] Installing NixOS from flake: ${REPO_PATH}#${HOST}"
nixos-install --flake "${REPO_PATH}#${HOST}" --no-root-passwd

# Path to tools in the TARGET system
TARGET_SW="/run/current-system/sw/bin"

# ╔══════════════════════════════════════════════════════════════════╗
# ║                         5. SET PASSWORDS                         ║
# ╚══════════════════════════════════════════════════════════════════╝
echo "[5/6] Setting password for root and ${TARGET_USER}"
while true; do
  read -rsp "Enter password for root and ${TARGET_USER}: " PASS1; echo
  read -rsp "Confirm password: " PASS2; echo
  [[ "$PASS1" == "$PASS2" ]] && break
  echo "Passwords do not match, try again."
done

# Use absolute paths inside chroot so PATH isn't needed
echo "root:${PASS1}" | chroot /mnt "${TARGET_SW}/chpasswd" \
  || { echo "Failed to set root password." >&2; exit 1; }

if chroot /mnt "${TARGET_SW}/getent" passwd "${TARGET_USER}" >/dev/null; then
  echo "${TARGET_USER}:${PASS1}" | chroot /mnt "${TARGET_SW}/chpasswd" \
    || { echo "Failed to set ${TARGET_USER} password." >&2; exit 1; }
else
  echo "WARN: user '${TARGET_USER}' not found in target system — ensure users.users.${TARGET_USER} is defined in your flake."
fi

unset PASS1 PASS2

# ╔══════════════════════════════════════════════════════════════════╗
# ║                              DONE                                ║
# ╚══════════════════════════════════════════════════════════════════╝
trap - ERR
echo "[6/6] Done. Reboot into your new system!"
