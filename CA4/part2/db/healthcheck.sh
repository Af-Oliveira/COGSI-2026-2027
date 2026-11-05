#!/bin/sh
# =============================================================================
# h2-healthcheck - healthy only if the server answers an SQL query over TCP
# -----------------------------------------------------------------------------
# An open port only shows that the JVM is listening; the query also checks the
# database file and the credentials, which is what the web service needs.
# The JIT is limited to its first tier: the check is a short-lived JVM.
# =============================================================================
set -eu
exec java -XX:TieredStopAtLevel=1 -cp /opt/h2/h2.jar org.h2.tools.Shell \
    -url "jdbc:h2:tcp://localhost:${H2_PORT}/./${DB_NAME}" \
    -user "$DB_USER" -password "$DB_PASSWORD" \
    -sql "SELECT 1" >/dev/null
