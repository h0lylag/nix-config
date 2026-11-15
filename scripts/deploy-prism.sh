#!/usr/bin/env bash
set -euo pipefail

# deploy-prism.sh - Update the Prism v2 flake input in this Nix repo
#
# This script:
# 1. Runs `nix flake update prism` (flake.lock only)
# 2. Commits the lock change locally
#
# Usage: scripts/deploy-prism.sh

INPUT="prism"
LOCK_FILE="flake.lock"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log_info() { echo -e "${GREEN}●${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }
log_step() { echo -e "\n${BOLD}${CYAN}▶ $*${NC}"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }

locked_rev() {
    jq -r --arg n "$INPUT" '.nodes[$n].locked.rev // empty' "$LOCK_FILE"
}

cd "$(git rev-parse --show-toplevel)"

log_step "Step 1: Pre-flight Checks"
if [[ ! -f flake.nix || ! -f "$LOCK_FILE" ]]; then
    log_error "flake.nix or $LOCK_FILE not found"
    exit 1
fi
if ! git diff --quiet -- "$LOCK_FILE" || ! git diff --cached --quiet -- "$LOCK_FILE"; then
    log_error "$LOCK_FILE has uncommitted changes; commit or stash them first"
    exit 1
fi
log_success "$LOCK_FILE is clean"

CURRENT_REV=$(locked_rev)
if [[ ! "$CURRENT_REV" =~ ^[0-9a-f]{40}$ ]]; then
    log_error "Could not find a locked revision for input '$INPUT'"
    exit 1
fi
echo -e "  ${DIM}Current:${NC} ${YELLOW}${CURRENT_REV:0:7}${NC}"

log_step "Step 2: Updating Flake Input"
log_info "Running ${BLUE}nix flake update $INPUT${NC}..."
nix flake update "$INPUT"

NEW_REV=$(locked_rev)
echo -e "  ${DIM}Latest:${NC}  ${CYAN}${NEW_REV:0:7}${NC}"

if [[ "$CURRENT_REV" == "$NEW_REV" ]]; then
    log_info "Already at latest revision; nothing to commit"
    exit 0
fi

log_step "Step 3: Committing Changes"
git add "$LOCK_FILE"
git commit --only "$LOCK_FILE" -m "chore(flake): update $INPUT to ${NEW_REV:0:7}"
log_success "${BOLD}$INPUT updated ${CURRENT_REV:0:7} → ${NEW_REV:0:7} and committed locally${NC}"
