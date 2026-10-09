#!/bin/bash
# =============================================================================
# provisioning/deploy.sh - COGSI CA2 / Part 1
# -----------------------------------------------------------------------------
# Installs the built applications outside the working copy and describes how
# they run:
#   /opt/bookstore/bookstore.jar            executable Spring Boot jar
#   /etc/bookstore/application.properties   H2 on disk, in the synced folder
#   /opt/chat-server/                       chat server jar and its libraries
#   /etc/systemd/system/*.service           one systemd unit per application
#
# The application.properties written here is loaded on top of the one packaged
# in the jar (spring.config.additional-location), so the sources in CA1 keep
# their in-memory default and only this VM switches to a file database.
#
# Environment (set by the Vagrantfile):
#   REPO_DIR         working copy of the group repository
#   H2_DATA_DIR      mount point of the synced folder dedicated to H2
#   BOOKSTORE_PORT   HTTP port of the Bookstore
#   CHAT_PORT        TCP port of the chat server
#
# Idempotence: a file is only replaced when its content differs. Each change
# leaves a marker for start.sh, which restarts only the affected service.
# =============================================================================

set -euo pipefail

REPO_DIR="${REPO_DIR:?REPO_DIR is required}"
H2_DATA_DIR="${H2_DATA_DIR:-/h2-data}"
BOOKSTORE_PORT="${BOOKSTORE_PORT:-8080}"
CHAT_PORT="${CHAT_PORT:-59001}"

APP_USER="vagrant"
RESTART_DIR="/run/cogsi-restart"

mkdir -p "$RESTART_DIR"

# Copies a file to its destination unless an identical copy is already there.
install_if_changed() {
    local source=$1 target=$2 service=$3

    if [ -f "$target" ] && cmp -s "$source" "$target"; then
        echo "[OK] $target is up to date."
    else
        install -D -m 0644 "$source" "$target"
        touch "$RESTART_DIR/$service"
        echo "[DEPLOY] $target"
    fi
}

# Same as install_if_changed, taking the desired content from standard input.
write_if_changed() {
    local target=$1 service=$2 staged

    staged=$(mktemp)
    cat >"$staged"
    install_if_changed "$staged" "$target" "$service"
    rm -f "$staged"
}

# Prints the newest jar matching a pattern, or nothing when it was not built.
find_jar() {
    local directory=$1 pattern=$2

    find "$directory" -maxdepth 1 -name "$pattern" ! -name '*-plain.jar' 2>/dev/null \
        | sort | tail -n 1 || true
}

echo "================================================="
echo "Deploying the applications..."
echo "================================================="

# -----------------------------------------------------------------------------
# Bookstore (Spring Boot)
# -----------------------------------------------------------------------------
bookstore_jar=$(find_jar "$REPO_DIR/CA1/part2/build/libs" 'bookstore-*.jar')

if [ -z "$bookstore_jar" ]; then
    echo "[SKIP] Bookstore jar not found - provision with BUILD_APPS=true first."
else
    install_if_changed "$bookstore_jar" /opt/bookstore/bookstore.jar bookstore

    write_if_changed /etc/bookstore/application.properties bookstore <<EOF
# Managed by provisioning/deploy.sh - manual changes are overwritten.

# H2 in embedded file mode. The database lives in the synced folder dedicated
# to persistent storage, so the data survives a restart, a reload and even the
# destruction of the VM.
spring.datasource.url=jdbc:h2:file:${H2_DATA_DIR}/bookstore;DB_CLOSE_ON_EXIT=FALSE
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=

# Keep the existing schema and rows between executions.
spring.jpa.hibernate.ddl-auto=update

server.port=${BOOKSTORE_PORT}

# The SQL trace is useful in the IDE but floods the service journal.
spring.jpa.show-sql=false
EOF

    write_if_changed /etc/systemd/system/bookstore.service bookstore <<EOF
# Managed by provisioning/deploy.sh - manual changes are overwritten.
[Unit]
Description=Bookstore Spring Boot application (COGSI)
After=network-online.target
Wants=network-online.target
# Refuse to start on the empty mount point: H2 would silently create a new
# database on the VM disk instead of using the one in the synced folder.
AssertPathIsMountPoint=${H2_DATA_DIR}

[Service]
User=${APP_USER}
WorkingDirectory=/opt/bookstore
ExecStart=/usr/bin/java -jar /opt/bookstore/bookstore.jar --spring.config.additional-location=file:/etc/bookstore/
# The JVM exits with 143 when it is stopped with SIGTERM.
SuccessExitStatus=143
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

# -----------------------------------------------------------------------------
# Chat server (Gradle demo)
# -----------------------------------------------------------------------------
chat_libs="$REPO_DIR/CA1/part1/app/build/libs"
chat_jar=$(find_jar "$chat_libs" 'chat-server-*.jar')

if [ -z "$chat_jar" ]; then
    echo "[SKIP] Chat server jar not found - provision with BUILD_APPS=true first."
else
    install_if_changed "$chat_jar" /opt/chat-server/chat-server.jar chat-server

    # The dependency set is replaced as a whole, so a library removed or
    # upgraded in the build does not linger on the classpath.
    if diff -rq "$chat_libs/lib" /opt/chat-server/lib >/dev/null 2>&1; then
        echo "[OK] /opt/chat-server/lib is up to date."
    else
        rm -rf /opt/chat-server/lib
        install -d -m 0755 /opt/chat-server/lib
        install -m 0644 "$chat_libs"/lib/*.jar /opt/chat-server/lib/
        touch "$RESTART_DIR/chat-server"
        echo "[DEPLOY] /opt/chat-server/lib"
    fi

    write_if_changed /etc/systemd/system/chat-server.service chat-server <<EOF
# Managed by provisioning/deploy.sh - manual changes are overwritten.
[Unit]
Description=Chat server from the Gradle demo application (COGSI)
After=network-online.target
Wants=network-online.target

[Service]
User=${APP_USER}
WorkingDirectory=/opt/chat-server
ExecStart=/usr/bin/java -cp /opt/chat-server/chat-server.jar:/opt/chat-server/lib/* org.example.ChatServerApp ${CHAT_PORT}
# The JVM exits with 143 when it is stopped with SIGTERM.
SuccessExitStatus=143
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload

echo "================================================="
echo "Deployment complete."
echo "================================================="
