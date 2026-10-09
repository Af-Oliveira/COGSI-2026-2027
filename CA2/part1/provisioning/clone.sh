#!/bin/bash
# =============================================================================
# provisioning/clone.sh - COGSI CA2 / Part 1
# -----------------------------------------------------------------------------
# Clones the group repository inside the VM, or fast-forwards the existing
# working copy when the VM has already been provisioned.
#
# Environment (set by the Vagrantfile):
#   CLONE_REPO     "true" to run this step, anything else to skip it
#   REPO_URL       HTTPS URL of the repository
#   REPO_BRANCH    branch to check out
#   REPO_DIR       destination directory inside the VM
#   GITHUB_TOKEN   optional access token, required only for a private repository
#
# Runs as the vagrant user (privileged: false).
# =============================================================================

set -euo pipefail

CLONE_REPO="${CLONE_REPO:-true}"
REPO_URL="${REPO_URL:?REPO_URL is required}"
REPO_BRANCH="${REPO_BRANCH:-main}"
REPO_DIR="${REPO_DIR:-$HOME/COGSI-2026-2027}"

if [ "$CLONE_REPO" != "true" ]; then
    echo "[SKIP] CLONE_REPO=$CLONE_REPO - the repository was not cloned or updated."
    exit 0
fi

# The token is sent as an HTTP header for this invocation only. It is never
# written to the URL, to .git/config or to the provisioning output.
git_auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    credentials=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 -w0)
    git_auth=(-c "http.extraHeader=Authorization: Basic $credentials")
    echo "[INFO] Using the access token provided in GITHUB_TOKEN."
fi

if [ -d "$REPO_DIR/.git" ]; then
    echo "[OK] Repository already cloned in $REPO_DIR - updating $REPO_BRANCH."
    git "${git_auth[@]}" -C "$REPO_DIR" fetch --quiet --prune origin
    git -C "$REPO_DIR" checkout --quiet "$REPO_BRANCH"
    git -C "$REPO_DIR" merge --quiet --ff-only "origin/$REPO_BRANCH"
else
    echo "[CLONE] Cloning $REPO_URL ($REPO_BRANCH) into $REPO_DIR"
    git "${git_auth[@]}" clone --quiet --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi

echo "[INFO] HEAD is now at $(git -C "$REPO_DIR" log -1 --format='%h %s')"
