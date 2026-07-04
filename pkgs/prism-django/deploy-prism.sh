#!/usr/bin/env bash
set -euo pipefail

# deploy-prism.sh - Update prism-django package pin in this Nix repo
#
# This script:
# 1. Fetches the latest commit hash from prism-django repo
# 2. Updates the revision in the Nix package file
# 3. Commits the change locally
#
# Usage: ./deploy-prism.sh

PKG_FILE="pkgs/prism-django/package.nix"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}●${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
}

log_step() {
    echo -e "\n${BOLD}${CYAN}▶ $*${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_header() {
    echo -e "\n${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║${NC}          ${BOLD}Prism Django Rev Update Script${NC}            ${BOLD}${MAGENTA}║${NC}"
    echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
}

print_box() {
    local color=$1
    shift
    echo -e "\n${color}┌────────────────────────────────────────────────────────┐${NC}"
    for line in "$@"; do
        # Calculate padding by stripping color codes for length calculation
        local stripped=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
        local pad=$((54 - ${#stripped}))
        printf "${color}│${NC} %b%*s ${color}│${NC}\n" "$line" "$pad" ""
    done
    echo -e "${color}└────────────────────────────────────────────────────────┘${NC}"
}

print_header

# Ensure we're in the nixos-config directory
log_step "Step 1: Pre-flight Checks"
if [[ ! -f "flake.nix" ]]; then
    log_error "Must be run from the .nixos-config directory"
    exit 1
fi
log_success "Running from correct directory"

if ! git diff --quiet -- "$PKG_FILE" || ! git diff --cached --quiet -- "$PKG_FILE"; then
    log_error "$PKG_FILE has uncommitted changes; commit or stash them before running this script"
    exit 1
fi
log_success "Package file is clean"

REPO_URL=$(grep -oP 'url = "\K[^"]+' "$PKG_FILE" | head -n1)
if [[ -z "$REPO_URL" ]]; then
    log_error "Could not find source URL in $PKG_FILE"
    exit 1
fi

# Step 1: Fetch latest commit hash
log_step "Step 2: Fetching Latest Revision"
log_info "Querying ${BLUE}$REPO_URL${NC}..."
NEW_REV=$(git ls-remote --heads "$REPO_URL" refs/heads/main | awk 'NR == 1 { print $1 }')

if [[ ! "$NEW_REV" =~ ^[0-9a-f]{40}$ ]]; then
    log_error "Failed to fetch a valid revision for refs/heads/main"
    printf 'Received: %q\n' "$NEW_REV"
    exit 1
fi

log_success "Retrieved latest revision"
echo -e "  ${DIM}Commit:${NC} ${CYAN}${NEW_REV:0:12}${NC}"

# Step 2: Get current revision from the package file
log_step "Step 3: Checking Current Revision"
CURRENT_REV=$(grep -oP 'rev = "\K[0-9a-f]{40}' "$PKG_FILE" || echo "")

if [[ -z "$CURRENT_REV" ]]; then
    log_error "Could not find current revision in $PKG_FILE"
    exit 1
fi

echo -e "  ${DIM}Current:${NC}  ${YELLOW}${CURRENT_REV:0:12}${NC}"
echo -e "  ${DIM}Latest:${NC}   ${CYAN}${NEW_REV:0:12}${NC}"

if [[ "$CURRENT_REV" == "$NEW_REV" ]]; then
    print_box "$YELLOW" \
        "No changes detected" \
        "Already at latest revision: ${NEW_REV:0:12}"
    log_info "Skipping local update"
else
    print_box "$GREEN" \
        "Changes detected!" \
        "Current: ${CURRENT_REV:0:12}" \
        "Latest:  ${NEW_REV:0:12}" \
        "" \
        "This will update the package and commit the pin locally."

    log_step "Step 4: Updating Local Package"
    log_info "Modifying ${BLUE}$PKG_FILE${NC}..."

    # Update the revision in the file
    sed -i "s/rev = \"[0-9a-f]\{40\}\"/rev = \"$NEW_REV\"/" "$PKG_FILE"

    # Verify the change
    if ! grep -q "rev = \"$NEW_REV\"" "$PKG_FILE"; then
        log_error "Failed to update revision in $PKG_FILE"
        exit 1
    fi

    log_success "Package file updated"

    # Step 3: Commit locally
    log_step "Step 5: Committing Changes"
    log_info "Staging changes..."
    git add "$PKG_FILE"

    log_info "Creating commit..."
    git commit --only "$PKG_FILE" -m "prism-django: update to $NEW_REV"
    log_success "Commit created"

    print_box "$GREEN" \
        "Local Update Successful!" \
        "" \
        "Revision: ${NEW_REV:0:12}" \
        "Commit:   $(git rev-parse --short HEAD)"

    echo ""
    log_success "${BOLD}prism-django pin updated to ${CYAN}${NEW_REV:0:12}${NC}${GREEN} and committed locally${NC}"
    echo ""
fi
