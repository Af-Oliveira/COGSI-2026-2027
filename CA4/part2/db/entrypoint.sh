#!/bin/sh
# =============================================================================
# h2-entrypoint - create the database on the first start, then run the server
# -----------------------------------------------------------------------------
# CA2 started H2 with -ifNotExists, which lets any client that reaches the
# port create a database with credentials of its choice. Here the database is
# created locally, once, with DB_USER and DB_PASSWORD, and the server runs
# without -ifNotExists: a client can only open the existing database.
# =============================================================================
set -eu

: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${DB_NAME:=bookstore}"
: "${H2_PORT:=9092}"
: "${H2_DATA_DIR:=/var/lib/h2}"

H2_JAR=/opt/h2/h2.jar

if [ -f "$H2_DATA_DIR/$DB_NAME.mv.db" ]; then
    echo "[OK] Database $DB_NAME found in $H2_DATA_DIR (kept from the volume)."
else
    echo "[INIT] Creating database $DB_NAME in $H2_DATA_DIR, owned by $DB_USER."
    # Opening an embedded database that does not exist creates it, and the
    # user of that first connection becomes its administrator.
    java -cp "$H2_JAR" org.h2.tools.Shell \
        -url "jdbc:h2:$H2_DATA_DIR/$DB_NAME" -user "$DB_USER" -password "$DB_PASSWORD" \
        -sql "SELECT 1" >/dev/null
fi

echo "[START] H2 TCP server on port $H2_PORT, base directory $H2_DATA_DIR."
# exec: java replaces the shell as PID 1 and receives SIGTERM on docker stop.
exec java ${JAVA_OPTS:-} -cp "$H2_JAR" org.h2.tools.Server \
    -tcp -tcpAllowOthers -tcpPort "$H2_PORT" -baseDir "$H2_DATA_DIR"
