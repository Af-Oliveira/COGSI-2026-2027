#!/bin/bash
# =============================================================================
# tunnel.sh - COGSI CA2 / Alternative (Multipass + cloud-init)
# -----------------------------------------------------------------------------
# Publishes the proxy instance on http://localhost:TUNNEL_PORT with an SSH
# local port forward, authenticated with the custom key of the proxy. It plays
# the role of the forwarded port of the Vagrant solution.
#
# The host has no IPv4 address in the private network of the instances, so the
# SSH connection uses the IPv6 link-local address of the proxy, which is always
# reachable on the bridged host network without any host configuration.
#
# Usage: ./tunnel.sh        (stays in the foreground; stop it with Ctrl+C)
# =============================================================================

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cd "$SCRIPT_DIR"

# Link-local address of the private interface, found by its MAC address.
device=$(in_instance proxy ip -o link | awk -v mac="${MAC[proxy]}" 'index($0, mac) { sub(":", "", $2); print $2 }')
address=$(in_instance proxy ip -6 -o addr show dev "$device" scope link | awk '{ sub("/.*", "", $4); print $4 }')
if [ -z "$address" ]; then
    echo "[ERROR] The proxy instance has no link-local address on $device." >&2
    exit 1
fi

# A link-local address is only meaningful together with the host interface it
# is reached through: its index on Windows, its name elsewhere.
if command -v powershell.exe >/dev/null 2>&1; then
    scope=$(powershell.exe -NoProfile -Command "(Get-NetAdapter -Name '$BRIDGE').ifIndex" | tr -d '\r')
    ssh_client=ssh.exe
    known_hosts=NUL
else
    scope=$BRIDGE
    ssh_client=ssh
    known_hosts=/dev/null
fi

echo "[INFO] Forwarding http://localhost:$TUNNEL_PORT -> proxy:80 through ${address}%${scope}"
echo "[INFO] Press Ctrl+C to close the tunnel."
exec "$ssh_client" -N \
    -i "keys/proxy_ed25519" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile="$known_hosts" \
    -o ExitOnForwardFailure=yes \
    -L "127.0.0.1:$TUNNEL_PORT:127.0.0.1:80" \
    "ubuntu@${address}%${scope}"
