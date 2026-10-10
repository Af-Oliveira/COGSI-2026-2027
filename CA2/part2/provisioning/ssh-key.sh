#!/bin/bash
# =============================================================================
# provisioning/ssh-key.sh - COGSI CA2 / Part 2
# -----------------------------------------------------------------------------
# Makes the key pair generated for this machine the only way to log in as the
# vagrant user. The box ships with the Vagrant insecure public key, whose
# private half is public knowledge; it is removed here.
#
# Environment (set by the Vagrantfile):
#   PUBLIC_KEY   public key generated on the host for this machine
#
# Idempotence: authorized_keys is rewritten only when it differs from the key.
# Runs as the vagrant user (privileged: false).
# =============================================================================

set -euo pipefail

PUBLIC_KEY="${PUBLIC_KEY:?PUBLIC_KEY is required}"
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"

if [ -f "$AUTHORIZED_KEYS" ] && [ "$(cat "$AUTHORIZED_KEYS")" = "$PUBLIC_KEY" ]; then
    echo "[OK] authorized_keys already contains only the custom key."
    exit 0
fi

install -d -m 0700 "$HOME/.ssh"
# Written to a temporary file and renamed, so the session that runs this script
# never sees a half-written file.
printf '%s\n' "$PUBLIC_KEY" >"$AUTHORIZED_KEYS.new"
chmod 0600 "$AUTHORIZED_KEYS.new"
mv "$AUTHORIZED_KEYS.new" "$AUTHORIZED_KEYS"

echo "[CONFIG] Custom key installed; the Vagrant insecure key was removed."
echo "[INFO] $(ssh-keygen -lf "$AUTHORIZED_KEYS")"
