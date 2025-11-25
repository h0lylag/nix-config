#!/usr/bin/env bash
set -euo pipefail

# deploy-prism.sh - Automated deployment script for prism-django updates
#
# This script:
# 1. Fetches the latest commit hash from prism-django repo
# 2. Updates the revision in the Nix package file
# 3. Commits and pushes the change to GitHub
# 4. SSHs into midship to pull and rebuild the system
#
# Usage: ./deploy-prism.sh

REPO_URL="git@github.com:h0lylag/prism-django.git"
PKG_FILE="pkgs/prism-django/default.nix"
REMOTE_HOST="midship"
REMOTE_PATH=".nixos-config"

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

# Unicode symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${BLUE}→${NC}"
STAR="${YELLOW}★${NC}"

log_info() {
    echo -e "${GREEN}●${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC}  $*"
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
    echo -e "${BOLD}${MAGENTA}║${NC}        ${BOLD}Prism Django Deployment Script${NC}              ${BOLD}${MAGENTA}║${NC}"
    echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
}

print_separator() {
    echo -e "${DIM}────────────────────────────────────────────────────────${NC}"
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

# Step 1: Fetch latest commit hash
log_step "Step 2: Fetching Latest Revision"
log_info "Querying ${BLUE}$REPO_URL${NC}..."
NEW_REV=$(git ls-remote "$REPO_URL" main | awk '{print $1}')

if [[ -z "$NEW_REV" ]]; then
    log_error "Failed to fetch latest revision"
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

LOCAL_CHANGES=false

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
        "This will update the package and rebuild the system."

    LOCAL_CHANGES=true

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

    # Step 3: Commit and push
    log_step "Step 5: Committing Changes"
    log_info "Staging changes..."
    git add "$PKG_FILE"

    log_info "Creating commit..."
    git commit -m "prism-django: update to $NEW_REV"
    log_success "Commit created"

    log_info "Pushing to GitHub..."
    git push origin main
    log_success "Changes pushed to remote"
fi

# Step 4: Deploy to midship
STEP_NUM=6
if [[ "$LOCAL_CHANGES" == "false" ]]; then
    STEP_NUM=4
fi

log_step "Step $STEP_NUM: Deploying to Remote Host"
log_info "Target: ${BLUE}$REMOTE_HOST${NC}"

# Check if we can reach the remote host
log_info "Testing connection..."
if ! ssh -o ConnectTimeout=5 "$REMOTE_HOST" "exit" 2>/dev/null; then
    log_error "Cannot connect to $REMOTE_HOST"
    exit 1
fi
log_success "Connection established"

# Execute remote commands with PTY allocation for sudo
log_info "Pulling latest changes on ${BLUE}$REMOTE_HOST${NC}..."
if ssh "$REMOTE_HOST" "cd ~/.nixos-config && git pull origin main" > /tmp/git-pull-output.txt 2>&1; then
    if grep -q "Already up to date" /tmp/git-pull-output.txt; then
        log_warn "Remote already up to date"
    else
        log_success "Remote repository updated"
    fi
else
    log_error "Failed to pull changes on remote"
    cat /tmp/git-pull-output.txt
    exit 1
fi

print_separator
echo -e "${BOLD}${CYAN}Starting NixOS rebuild on $REMOTE_HOST...${NC}"
print_separator

# Capture start time
START_TIME=$(date +%s)

if ssh -t "$REMOTE_HOST" "cd ~/.nixos-config && sudo nixos-rebuild switch --flake .#midship"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    print_box "$GREEN" \
        "Deployment Successful! ✓" \
        "" \
        "Host:     $REMOTE_HOST" \
        "Revision: ${NEW_REV:0:12}" \
        "Duration: ${DURATION}s"

    echo ""
    log_success "${BOLD}prism-django updated to ${CYAN}${NEW_REV:0:12}${NC}${GREEN} on ${BLUE}$REMOTE_HOST${NC}"
    echo ""

    exit 0
else
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    print_box "$RED" \
        "Deployment Failed ✗" \
        "" \
        "Host:     $REMOTE_HOST" \
        "Duration: ${DURATION}s" \
        "" \
        "Check the output above for errors."

    exit 1
fi
