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
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Ensure we're in the nixos-config directory
if [[ ! -f "flake.nix" ]]; then
    log_error "Must be run from the .nixos-config directory"
    exit 1
fi

# Step 1: Fetch latest commit hash
log_info "Fetching latest commit from $REPO_URL..."
NEW_REV=$(git ls-remote "$REPO_URL" main | awk '{print $1}')

if [[ -z "$NEW_REV" ]]; then
    log_error "Failed to fetch latest revision"
    exit 1
fi

log_info "Latest revision: $NEW_REV"

# Step 2: Get current revision from the package file
CURRENT_REV=$(grep -oP 'rev = "\K[0-9a-f]{40}' "$PKG_FILE" || echo "")

if [[ "$CURRENT_REV" == "$NEW_REV" ]]; then
    log_warn "Already at latest revision ($NEW_REV)"
    log_info "Skipping local update, checking remote..."
else
    log_info "Current revision: $CURRENT_REV"
    log_info "Updating $PKG_FILE..."
    
    # Update the revision in the file
    sed -i "s/rev = \"[0-9a-f]\{40\}\"/rev = \"$NEW_REV\"/" "$PKG_FILE"
    
    # Verify the change
    if ! grep -q "rev = \"$NEW_REV\"" "$PKG_FILE"; then
        log_error "Failed to update revision in $PKG_FILE"
        exit 1
    fi
    
    log_info "Successfully updated revision"
    
    # Step 3: Commit and push
    log_info "Committing changes..."
    git add "$PKG_FILE"
    git commit -m "prism-django: update to $NEW_REV"
    
    log_info "Pushing to GitHub..."
    git push origin main
    
    log_info "Local repository updated and pushed"
fi

# Step 4: Deploy to midship
log_info "Deploying to $REMOTE_HOST..."

# Check if we can reach the remote host
if ! ssh -o ConnectTimeout=5 "$REMOTE_HOST" "exit" 2>/dev/null; then
    log_error "Cannot connect to $REMOTE_HOST"
    exit 1
fi

log_info "Connected to $REMOTE_HOST"

# Execute remote commands with PTY allocation for sudo
log_info "Pulling latest changes on $REMOTE_HOST..."
ssh "$REMOTE_HOST" "cd ~/.nixos-config && git pull origin main"

log_info "Rebuilding system on $REMOTE_HOST..."
ssh -t "$REMOTE_HOST" "cd ~/.nixos-config && sudo nixos-rebuild switch --flake .#midship"

if [[ $? -eq 0 ]]; then
    log_info "Deployment successful!"
    log_info "prism-django updated to $NEW_REV on $REMOTE_HOST"
else
    log_error "Deployment failed"
    exit 1
fi
