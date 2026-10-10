#!/bin/bash
# =============================================================================
# down.sh - COGSI CA2 / Alternative (Multipass + cloud-init)
# -----------------------------------------------------------------------------
# Deletes the instances created by up.sh. Deleting the db instance deletes the
# database, which lives on its disk.
#
# Usage: ./down.sh                 delete the three instances
#        ./down.sh app proxy       delete only the given roles
#        KEEP_KEYS=false ./down.sh also remove the generated SSH keys
#
# Idempotence: an instance that does not exist is skipped.
# =============================================================================

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cd "$SCRIPT_DIR"

KEEP_KEYS="${KEEP_KEYS:-true}"
if [ "$#" -gt 0 ]; then
    roles=("$@")
else
    roles=("${ROLES[@]}")
fi

for role in "${roles[@]}"; do
    name=$(instance_name "$role")
    if [ -z "$(instance_state "$role")" ]; then
        echo "[OK] Instance $name does not exist."
    else
        # --purge removes the instance and its disk instead of keeping it in
        # the Multipass recycle bin.
        mp delete --purge "$name"
        echo "[DELETE] Instance $name deleted."
    fi

    if [ "$KEEP_KEYS" != "true" ]; then
        rm -f "keys/${role}_ed25519" "keys/${role}_ed25519.pub"
        echo "[DELETE] Key pair of $role removed."
    fi
done
