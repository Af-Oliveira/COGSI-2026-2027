#!/bin/bash
# =============================================================================
# provisioning/db.sh - COGSI CA2 / Part 2
# -----------------------------------------------------------------------------
# Turns the db machine into an H2 database server:
#   - Java runtime and the H2 engine jar (checksum verified)
#   - h2.service: H2 in server mode, as its own process, on the TCP port
#   - ufw: the H2 port is reachable only from the app machine
#
# Environment (set by the Vagrantfile):
#   H2_PORT   TCP port of the H2 server (9092)
#   DB_IP     private address of this machine
#   APP_IP    private address of the app machine, the only allowed client
#
# Idempotence: packages, jar, user, unit file and firewall rules are checked
# before being changed; the service is restarted only when its unit changed.
# =============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1

H2_PORT="${H2_PORT:-9092}"
DB_IP="${DB_IP:?DB_IP is required}"
APP_IP="${APP_IP:?APP_IP is required}"

# Must match the H2 version resolved by the Bookstore build (Spring Boot 4.1.1
# manages com.h2database:h2 2.4.240): client and server speak the same protocol.
H2_VERSION="2.4.240"
H2_SHA1="686180ad33981ad943fdc0ab381e619b2c2fdfe5"
H2_JAR="/opt/h2/h2-$H2_VERSION.jar"
H2_URL="https://repo1.maven.org/maven2/com/h2database/h2/$H2_VERSION/h2-$H2_VERSION.jar"
H2_DATA_DIR="/var/lib/h2"
H2_USER="h2"

echo "================================================="
echo "Provisioning the database machine..."
echo "================================================="

# -----------------------------------------------------------------------------
# Java runtime
# -----------------------------------------------------------------------------
if dpkg -s openjdk-21-jre-headless >/dev/null 2>&1; then
    echo "[OK] openjdk-21-jre-headless is already installed."
else
    echo "[INSTALL] Installing: openjdk-21-jre-headless"
    apt-get update -qq
    apt-get install -y -qq -o Dpkg::Use-Pty=0 openjdk-21-jre-headless >/dev/null
fi

# -----------------------------------------------------------------------------
# H2 engine
# -----------------------------------------------------------------------------
if [ -f "$H2_JAR" ] && echo "$H2_SHA1  $H2_JAR" | sha1sum --check --status; then
    echo "[OK] $H2_JAR is present and matches its checksum."
else
    echo "[DOWNLOAD] $H2_URL"
    install -d -m 0755 /opt/h2
    curl -fsSL -o "$H2_JAR.download" "$H2_URL"
    echo "$H2_SHA1  $H2_JAR.download" | sha1sum --check --status \
        || { echo "[ERROR] Checksum mismatch for the H2 jar." >&2; rm -f "$H2_JAR.download"; exit 1; }
    mv "$H2_JAR.download" "$H2_JAR"
fi

# -----------------------------------------------------------------------------
# Service account and data directory (on the VM disk, owned by the service)
# -----------------------------------------------------------------------------
if id "$H2_USER" >/dev/null 2>&1; then
    echo "[OK] User $H2_USER already exists."
else
    useradd --system --home-dir "$H2_DATA_DIR" --shell /usr/sbin/nologin "$H2_USER"
    echo "[CONFIG] System user $H2_USER created."
fi
install -d -m 0750 -o "$H2_USER" -g "$H2_USER" "$H2_DATA_DIR"

# -----------------------------------------------------------------------------
# systemd unit
# -----------------------------------------------------------------------------
unit=$(mktemp)
cat >"$unit" <<EOF
# Managed by provisioning/db.sh - manual changes are overwritten.
[Unit]
Description=H2 database engine in server mode (COGSI)
After=network-online.target
Wants=network-online.target

[Service]
User=$H2_USER
WorkingDirectory=$H2_DATA_DIR
# -tcp             start only the TCP server (no web console, no PG server)
# -tcpAllowOthers  accept connections from other machines, not only localhost
# -baseDir         every database lives under this directory
# -ifNotExists     let the first client connection create the database
ExecStart=/usr/bin/java -cp $H2_JAR org.h2.tools.Server -tcp -tcpAllowOthers -tcpPort $H2_PORT -baseDir $H2_DATA_DIR -ifNotExists
# The JVM exits with 143 when it is stopped with SIGTERM.
SuccessExitStatus=143
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if cmp -s "$unit" /etc/systemd/system/h2.service; then
    echo "[OK] /etc/systemd/system/h2.service is up to date."
    systemctl is-active --quiet h2 || systemctl start h2
else
    install -m 0644 "$unit" /etc/systemd/system/h2.service
    systemctl daemon-reload
    systemctl restart h2
    echo "[CONFIG] h2.service installed and (re)started."
fi
rm -f "$unit"
systemctl enable --quiet h2

# -----------------------------------------------------------------------------
# Firewall: only the app machine may reach the H2 port
# -----------------------------------------------------------------------------
# ufw reports "Skipping adding existing rule" when a rule is already present,
# so these commands can be repeated.
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
# SSH stays open: Vagrant manages the machine through it.
ufw allow 22/tcp >/dev/null
ufw allow from "$APP_IP" to "$DB_IP" port "$H2_PORT" proto tcp >/dev/null
ufw --force enable >/dev/null
echo "[INFO] Firewall active: $H2_PORT/tcp allowed only from $APP_IP."

# -----------------------------------------------------------------------------
# Wait for the TCP server
# -----------------------------------------------------------------------------
for _ in $(seq 1 60); do
    if nc -z 127.0.0.1 "$H2_PORT" 2>/dev/null; then
        echo "[READY] H2 is listening on port $H2_PORT."
        echo "================================================="
        echo "Database machine ready."
        echo "================================================="
        exit 0
    fi
    sleep 1
done

echo "[ERROR] H2 did not start listening on port $H2_PORT." >&2
journalctl -u h2 -n 30 --no-pager >&2
exit 1
