#!/bin/bash
# =============================================================================
# provisioning/app.sh - COGSI CA2 / Part 2
# -----------------------------------------------------------------------------
# Turns the app machine into the Bookstore application server:
#   - Git and JDK 21, clone of the group repository, build with the Gradle Wrapper
#   - /etc/bookstore/application.properties pointing to the H2 server on db
#   - wait-for-port: health check of the H2 TCP port, run before every start
#   - bookstore.service, enabled at boot
#   - ufw: the HTTP port is reachable only from the proxy machine
#
# Environment (set by the Vagrantfile):
#   REPO_URL, REPO_BRANCH, GITHUB_TOKEN   repository to clone
#   DB_HOST, H2_PORT                      address of the H2 server
#   DB_USER, DB_PASSWORD                  H2 credentials (from the host environment)
#   APP_PORT                              HTTP port of the Bookstore
#   PROXY_IP                              private address of the proxy machine
#
# Idempotence: every step checks the current state first, and the service is
# restarted only when its jar, configuration, health check or unit changed.
# =============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1

REPO_URL="${REPO_URL:?REPO_URL is required}"
REPO_BRANCH="${REPO_BRANCH:-main}"
DB_HOST="${DB_HOST:-db}"
H2_PORT="${H2_PORT:-9092}"
DB_USER="${DB_USER:?DB_USER is required}"
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD is required}"
APP_PORT="${APP_PORT:-8080}"
PROXY_IP="${PROXY_IP:?PROXY_IP is required}"

APP_USER="vagrant"
REPO_DIR="/home/$APP_USER/COGSI-2026-2027"
STARTUP_TIMEOUT=240
restart_needed=false

# Copies a file to its destination unless an identical copy is already there.
install_if_changed() {
    local source=$1 target=$2 mode=$3 group=${4:-root}

    if [ -f "$target" ] && cmp -s "$source" "$target"; then
        echo "[OK] $target is up to date."
    else
        install -D -m "$mode" -o root -g "$group" "$source" "$target"
        restart_needed=true
        echo "[DEPLOY] $target"
    fi
}

# Same as install_if_changed, taking the desired content from standard input.
write_if_changed() {
    local target=$1 mode=$2 group=${3:-root} staged

    staged=$(mktemp)
    cat >"$staged"
    install_if_changed "$staged" "$target" "$mode" "$group"
    rm -f "$staged"
}

echo "================================================="
echo "Provisioning the application machine..."
echo "================================================="

# -----------------------------------------------------------------------------
# Build dependencies
# -----------------------------------------------------------------------------
missing=()
for package in git openjdk-21-jdk-headless; do
    if dpkg -s "$package" >/dev/null 2>&1; then
        echo "[OK] $package is already installed."
    else
        missing+=("$package")
    fi
done
if [ "${#missing[@]}" -gt 0 ]; then
    echo "[INSTALL] Installing: ${missing[*]}"
    apt-get update -qq
    apt-get install -y -qq -o Dpkg::Use-Pty=0 "${missing[@]}" >/dev/null
fi

# -----------------------------------------------------------------------------
# Clone or update the group repository (as the application user)
# -----------------------------------------------------------------------------
# The token is sent as an HTTP header for this invocation only. It is never
# written to the URL, to .git/config or to the provisioning output.
git_auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    credentials=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 -w0)
    git_auth=(-c "http.extraHeader=Authorization: Basic $credentials")
fi
as_app() { sudo -u "$APP_USER" -H "$@"; }

if [ -d "$REPO_DIR/.git" ]; then
    echo "[OK] Repository already cloned in $REPO_DIR - updating $REPO_BRANCH."
    as_app git "${git_auth[@]}" -C "$REPO_DIR" fetch --quiet --prune origin
    as_app git -C "$REPO_DIR" checkout --quiet "$REPO_BRANCH"
    as_app git -C "$REPO_DIR" merge --quiet --ff-only "origin/$REPO_BRANCH"
else
    echo "[CLONE] Cloning $REPO_URL ($REPO_BRANCH) into $REPO_DIR"
    as_app git "${git_auth[@]}" clone --quiet --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi

# -----------------------------------------------------------------------------
# Build the Gradle version of the Bookstore
# -----------------------------------------------------------------------------
echo "[BUILD] CA1/part2: ./gradlew bootJar"
(cd "$REPO_DIR/CA1/part2" && as_app ./gradlew --no-daemon --console=plain bootJar)

bookstore_jar=$(find "$REPO_DIR/CA1/part2/build/libs" -maxdepth 1 -name 'bookstore-*.jar' \
    ! -name '*-plain.jar' | sort | tail -n 1)
install_if_changed "$bookstore_jar" /opt/bookstore/bookstore.jar 0644

# -----------------------------------------------------------------------------
# Datasource: H2 server on the db machine, over the private network
# -----------------------------------------------------------------------------
# Readable only by root and by the application user because it holds the
# database password, which comes from the host environment.
write_if_changed /etc/bookstore/application.properties 0640 "$APP_USER" <<EOF
# Managed by provisioning/app.sh - manual changes are overwritten.

# H2 in server mode: the application is a JDBC client of the engine that runs
# on the db machine. "./bookstore" is relative to the base directory of the
# server.
spring.datasource.url=jdbc:h2:tcp://${DB_HOST}:${H2_PORT}/./bookstore
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}

# Keep the existing schema and rows between executions.
spring.jpa.hibernate.ddl-auto=update

server.port=${APP_PORT}

# The SQL trace is useful in the IDE but floods the service journal.
spring.jpa.show-sql=false
EOF

# -----------------------------------------------------------------------------
# Health check of a TCP port
# -----------------------------------------------------------------------------
write_if_changed /usr/local/bin/wait-for-port 0755 <<'EOF'
#!/bin/bash
# Managed by provisioning/app.sh - manual changes are overwritten.
#
# Usage: wait-for-port <host> <port> [timeout in seconds]
# Succeeds as soon as a TCP connection to host:port is accepted; fails when the
# timeout expires, so that the service depending on it is not started.
set -u

host=${1:?host is required}
port=${2:?port is required}
timeout=${3:-60}

for ((elapsed = 0; elapsed < timeout; elapsed += 2)); do
    if nc -z -w 2 "$host" "$port" 2>/dev/null; then
        echo "$host:$port is accepting connections (after ${elapsed}s)."
        exit 0
    fi
    echo "Waiting for $host:$port (${elapsed}s of ${timeout}s)..."
    sleep 2
done

echo "$host:$port is not reachable after ${timeout}s - giving up." >&2
exit 1
EOF

# -----------------------------------------------------------------------------
# systemd unit
# -----------------------------------------------------------------------------
write_if_changed /etc/systemd/system/bookstore.service 0644 <<EOF
# Managed by provisioning/app.sh - manual changes are overwritten.
[Unit]
Description=Bookstore Spring Boot application (COGSI)
After=network-online.target
Wants=network-online.target

[Service]
User=${APP_USER}
WorkingDirectory=/opt/bookstore
# Health check: the application is only launched once the H2 TCP port answers.
ExecStartPre=/usr/local/bin/wait-for-port ${DB_HOST} ${H2_PORT} 60
ExecStart=/usr/bin/java -jar /opt/bookstore/bookstore.jar --spring.config.additional-location=file:/etc/bookstore/
TimeoutStartSec=120
# The JVM exits with 143 when it is stopped with SIGTERM.
SuccessExitStatus=143
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# -----------------------------------------------------------------------------
# Firewall: only the proxy may reach the application port
# -----------------------------------------------------------------------------
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
# SSH stays open: Vagrant manages the machine through it.
ufw allow 22/tcp >/dev/null
ufw allow from "$PROXY_IP" to any port "$APP_PORT" proto tcp >/dev/null
ufw --force enable >/dev/null
echo "[INFO] Firewall active: $APP_PORT/tcp allowed only from $PROXY_IP."

# -----------------------------------------------------------------------------
# Start the service and wait until it answers
# -----------------------------------------------------------------------------
systemctl daemon-reload
systemctl enable --quiet bookstore

if ! systemctl is-active --quiet bookstore; then
    echo "[START] bookstore"
    systemctl start bookstore
elif [ "$restart_needed" = true ]; then
    echo "[RESTART] bookstore - its deployment changed."
    systemctl restart bookstore
else
    echo "[OK] bookstore is already running."
fi

for ((elapsed = 0; elapsed < STARTUP_TIMEOUT; elapsed++)); do
    if curl -fsS "http://127.0.0.1:$APP_PORT/actuator/health" >/dev/null 2>&1; then
        echo "[READY] Bookstore on port $APP_PORT (after ${elapsed}s)"
        echo "================================================="
        echo "Application machine ready."
        echo "================================================="
        exit 0
    fi
    sleep 1
done

echo "[ERROR] The Bookstore did not become ready in ${STARTUP_TIMEOUT}s." >&2
journalctl -u bookstore -n 40 --no-pager >&2
exit 1
