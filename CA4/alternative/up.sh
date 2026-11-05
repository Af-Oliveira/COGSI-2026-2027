#!/usr/bin/env bash
# =============================================================================
# CA4 alternative - the Part 2 environment with rootless Podman and Quadlet
# -----------------------------------------------------------------------------
#  1. builds the db, web and proxy images with Podman (same Dockerfiles)
#  2. stores the database password as a Podman secret
#  3. writes one environment file per service from podman.env
#  4. installs the Quadlet units and starts proxy.service, which pulls in
#     web.service and db.service in order, each one waiting for the previous
#     to be healthy
#
# Usage (from the repository root):  CA4/alternative/up.sh
#        DB_PASSWORD=... CA4/alternative/up.sh   (non-interactive)
# =============================================================================
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
ALT=CA4/alternative
UNIT_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd
ENV_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/cogsi-ca4

# Podman only resolves the short names of the base images through these aliases.
export CONTAINERS_REGISTRIES_CONF="$PWD/$ALT/registries.conf"

[ -f "$ALT/podman.env" ] || cp "$ALT/podman.env.example" "$ALT/podman.env"
set -a
# shellcheck source=SCRIPTDIR/podman.env.example
. "$ALT/podman.env"
set +a

echo "[BUILD] images"
podman build -q -t localhost/cogsi-ca4-h2:2.4.240 CA4/part2/db
podman build -q -f CA4/part1/bookstore/v3/Dockerfile -t localhost/cogsi-ca4-bookstore:1.0.0 CA1/part2
podman build -q -t localhost/cogsi-ca4-proxy:1.0.0 CA4/part2/proxy

echo "[SECRET] cogsi-db-password"
if ! podman secret exists cogsi-db-password; then
    if [ -z "${DB_PASSWORD:-}" ]; then
        read -rsp "Database password: " DB_PASSWORD; echo
    fi
    [ -n "$DB_PASSWORD" ] || { echo "the password cannot be empty" >&2; exit 1; }
    printf '%s' "$DB_PASSWORD" | podman secret create cogsi-db-password - >/dev/null
fi

echo "[ENV] $ENV_DIR"
install -d -m 0700 "$ENV_DIR"
umask 077
cat >"$ENV_DIR/db.env" <<END
DB_NAME=$DB_NAME
DB_USER=$DB_USER
H2_PORT=$H2_PORT
H2_DATA_DIR=/var/lib/h2
JAVA_OPTS=$DB_JAVA_OPTS
END
cat >"$ENV_DIR/web.env" <<END
SERVER_PORT=$WEB_PORT
SPRING_DATASOURCE_URL=jdbc:h2:tcp://db:$H2_PORT/./$DB_NAME
SPRING_DATASOURCE_USERNAME=$DB_USER
SPRING_JPA_HIBERNATE_DDL_AUTO=$JPA_DDL_AUTO
SPRING_JPA_SHOW_SQL=$JPA_SHOW_SQL
SPRING_H2_CONSOLE_ENABLED=false
JAVA_TOOL_OPTIONS=$WEB_JAVA_OPTS
END
cat >"$ENV_DIR/proxy.env" <<END
NGINX_PORT=$PROXY_LISTEN_PORT
UPSTREAM_HOST=$PROXY_UPSTREAM_HOST
UPSTREAM_PORT=$WEB_PORT
PROXY_READ_TIMEOUT=$PROXY_READ_TIMEOUT
PROXY_PUBLISHED_PORT=$PROXY_PUBLISHED_PORT
END

echo "[UNITS] $UNIT_DIR"
install -d "$UNIT_DIR"
install -m 0644 "$ALT"/quadlet/cogsi-* "$UNIT_DIR"/
systemctl --user daemon-reload

echo "[START] cogsi-proxy.service (and its dependencies)"
systemctl --user start cogsi-proxy.service
systemctl --user --no-pager --lines=0 status cogsi-db.service cogsi-web.service cogsi-proxy.service | grep -E '●|Active:'
podman ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
