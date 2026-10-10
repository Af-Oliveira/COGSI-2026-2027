#!/bin/bash
# =============================================================================
# common.sh - COGSI CA2 / Alternative (Multipass + cloud-init)
# -----------------------------------------------------------------------------
# Settings and helpers shared by up.sh, tunnel.sh and down.sh. Sourced, not run.
#
# Host environment variables (all optional):
#   DB_USER, DB_PASSWORD        H2 credentials used by the Bookstore
#   REPO_URL, REPO_BRANCH       repository and branch cloned on the app instance
#   APP_MEMORY, APP_CPUS        resources of the app instance
#   IMAGE                       Ubuntu image launched by Multipass (default 24.04)
#   BRIDGE                      host network the private interface of every
#                               instance is attached to, as listed by
#                               `multipass networks` (default "Wi-Fi")
#   SUBNET                      first three octets of the private network
#                               (default 192.168.57)
#   NAME_PREFIX                 prefix of the instance names (default "ca2-")
#   LAUNCH_TIMEOUT              seconds to wait for cloud-init (default 2400)
#   TUNNEL_PORT                 host port opened by tunnel.sh (default 8080)
# =============================================================================

DB_USER="${DB_USER:-bookstore}"
DB_PASSWORD="${DB_PASSWORD:-bookstore-dev}"
REPO_URL="${REPO_URL:-https://github.com/Af-Oliveira/COGSI-2026-2027.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
APP_MEMORY="${APP_MEMORY:-2G}"
APP_CPUS="${APP_CPUS:-2}"
IMAGE="${IMAGE:-24.04}"
BRIDGE="${BRIDGE:-Wi-Fi}"
SUBNET="${SUBNET:-192.168.57}"
NAME_PREFIX="${NAME_PREFIX:-ca2-}"
LAUNCH_TIMEOUT="${LAUNCH_TIMEOUT:-2400}"
TUNNEL_PORT="${TUNNEL_PORT:-8080}"

H2_PORT=9092
APP_PORT=8080
# Must match the H2 version resolved by the Bookstore build (Spring Boot 4.1.1
# manages com.h2database:h2 2.4.240): client and server speak the same protocol.
H2_VERSION="2.4.240"
H2_SHA1="686180ad33981ad943fdc0ab381e619b2c2fdfe5"

# Roles in creation order: the database first, the proxy last. The database
# gets the least CPU and memory because H2 serves a single small client; the
# application needs enough memory for the Gradle build and the JVM.
ROLES=(db app proxy)
declare -A CPUS=([db]=1 [app]="$APP_CPUS" [proxy]=1)
declare -A MEMORY=([db]=768M [app]="$APP_MEMORY" [proxy]=512M)
declare -A DISK=([db]=5G [app]=8G [proxy]=4G)
# Private network: one static address and one fixed MAC address per instance.
# cloud-init finds the interface by its MAC address.
declare -A IP=([db]="$SUBNET.22" [app]="$SUBNET.21" [proxy]="$SUBNET.20")
declare -A MAC=([db]=52:54:00:c0:51:22 [app]=52:54:00:c0:51:21 [proxy]=52:54:00:c0:51:20)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The Multipass client: `multipass`, or `multipass.exe` when the scripts run in
# WSL on a Windows host.
MULTIPASS=""
for candidate in multipass multipass.exe "/mnt/c/Program Files/Multipass/bin/multipass.exe"; do
    if command -v "$candidate" >/dev/null 2>&1; then
        MULTIPASS=$candidate
        break
    fi
done
if [ -z "$MULTIPASS" ]; then
    echo "[ERROR] Multipass is not installed or not in the PATH." >&2
    exit 1
fi

# Runs the client without a terminal on its input and removes the carriage
# returns the Windows build prints.
mp() {
    "$MULTIPASS" "$@" </dev/null | tr -d '\r'
    return "${PIPESTATUS[0]}"
}

instance_name() { echo "${NAME_PREFIX}$1"; }

# Prints the state of an instance (Running, Stopped, ...) or nothing when it
# does not exist.
instance_state() {
    # `multipass info` fails for an unknown instance; that is an answer here.
    { mp info "$(instance_name "$1")" --format csv 2>/dev/null || true; } | awk -F, 'NR == 2 { print $2 }'
}

# Runs a command inside an instance.
in_instance() {
    local role=$1
    shift
    mp exec "$(instance_name "$role")" -- "$@"
}
