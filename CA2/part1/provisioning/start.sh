#!/bin/bash
# =============================================================================
# provisioning/start.sh - COGSI CA2 / Part 1
# -----------------------------------------------------------------------------
# Starts the Bookstore and the chat server and waits until both are answering.
#
# This provisioner is declared with run: "always". The services are not
# enabled at boot: Vagrant mounts the synced folder that holds the H2 database
# on every `vagrant up` and `vagrant reload`, so starting them from here
# guarantees that the folder is available and keeps the start-up under the
# control of START_SERVICES.
#
# Environment (set by the Vagrantfile):
#   START_SERVICES   "true" to run this step, anything else to skip it
#   H2_DATA_DIR      mount point of the synced folder dedicated to H2
#   BOOKSTORE_PORT   HTTP port of the Bookstore
#   CHAT_PORT        TCP port of the chat server
#
# Idempotence: a running service is left untouched, unless deploy.sh flagged
# that its jar, configuration or unit file changed.
# =============================================================================

set -euo pipefail

START_SERVICES="${START_SERVICES:-true}"
H2_DATA_DIR="${H2_DATA_DIR:-/h2-data}"
BOOKSTORE_PORT="${BOOKSTORE_PORT:-8080}"
CHAT_PORT="${CHAT_PORT:-59001}"

RESTART_DIR="/run/cogsi-restart"
STARTUP_TIMEOUT=180

if [ "$START_SERVICES" != "true" ]; then
    echo "[SKIP] START_SERVICES=$START_SERVICES - the services were not started."
    exit 0
fi

is_deployed() {
    [ -f "/etc/systemd/system/$1.service" ]
}

# Starts a service, or restarts it when its deployment changed.
ensure_running() {
    local service=$1

    if ! systemctl is-active --quiet "$service"; then
        echo "[START] $service"
        systemctl start "$service"
    elif [ -e "$RESTART_DIR/$service" ]; then
        echo "[RESTART] $service - its deployment changed."
        systemctl restart "$service"
    else
        echo "[OK] $service is already running."
    fi

    rm -f "$RESTART_DIR/$service"
}

# Polls a check command once per second until it succeeds or the timeout ends.
wait_until() {
    local service=$1 description=$2
    shift 2

    for ((elapsed = 0; elapsed < STARTUP_TIMEOUT; elapsed++)); do
        if "$@" >/dev/null 2>&1; then
            echo "[READY] $description (after ${elapsed}s)"
            return 0
        fi
        sleep 1
    done

    echo "[ERROR] $description did not become ready in ${STARTUP_TIMEOUT}s." >&2
    journalctl -u "$service" -n 40 --no-pager >&2
    return 1
}

is_listening() {
    ss -ltnH "sport = :$1" | grep -q .
}

echo "================================================="
echo "Starting the services..."
echo "================================================="

if ! mountpoint -q "$H2_DATA_DIR"; then
    echo "[ERROR] $H2_DATA_DIR is not mounted - the H2 synced folder is missing." >&2
    exit 1
fi

if is_deployed bookstore; then
    ensure_running bookstore
    wait_until bookstore "Bookstore on port $BOOKSTORE_PORT" \
        curl -fsS "http://127.0.0.1:$BOOKSTORE_PORT/actuator/health"
else
    echo "[SKIP] bookstore is not deployed - provision with BUILD_APPS=true first."
fi

# The chat port is only inspected, not connected to, so that the health check
# does not show up in the server as a client that joins and leaves.
if is_deployed chat-server; then
    ensure_running chat-server
    wait_until chat-server "Chat server on port $CHAT_PORT" is_listening "$CHAT_PORT"
else
    echo "[SKIP] chat-server is not deployed - provision with BUILD_APPS=true first."
fi

echo "================================================="
echo "Services started."
echo "================================================="
