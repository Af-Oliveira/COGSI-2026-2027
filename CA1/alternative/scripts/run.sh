#!/bin/sh
# Runs the Bookstore application from the development deployment directory.
# Usage: run.sh [--server.port=8085] [other Spring Boot arguments]
set -e

DIR=$(cd "$(dirname "$0")/.." && pwd)
JAR=$(ls "$DIR"/bookstore-*.jar 2>/dev/null | head -n 1)

if [ -z "$JAR" ]; then
    echo "No application jar found in $DIR" >&2
    exit 1
fi

exec java -jar "$JAR" "$@"
