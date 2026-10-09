#!/bin/bash
# =============================================================================
# provisioning/build.sh - COGSI CA2 / Part 1
# -----------------------------------------------------------------------------
# Builds the two CA1 applications from the cloned repository with their own
# Gradle Wrapper:
#   - CA1/part2  bootJar      executable Spring Boot jar of the Bookstore
#   - CA1/part1  packageApp   chat server jar plus its runtime dependencies
#
# Environment (set by the Vagrantfile):
#   BUILD_APPS   "true" to run this step, anything else to skip it
#   REPO_DIR     working copy of the group repository
#
# Idempotence: Gradle skips every task whose inputs have not changed, so a
# second run reports the tasks as UP-TO-DATE and produces the same artifacts.
#
# Runs as the vagrant user (privileged: false).
# =============================================================================

set -euo pipefail

BUILD_APPS="${BUILD_APPS:-true}"
REPO_DIR="${REPO_DIR:-$HOME/COGSI-2026-2027}"

if [ "$BUILD_APPS" != "true" ]; then
    echo "[SKIP] BUILD_APPS=$BUILD_APPS - the applications were not built."
    exit 0
fi

if [ ! -d "$REPO_DIR/CA1" ]; then
    echo "[ERROR] $REPO_DIR/CA1 not found. Provision with CLONE_REPO=true first." >&2
    exit 1
fi

# --no-daemon: the build runs once per provisioning, so a resident Gradle
# daemon would only keep memory away from the applications.
run_gradle() {
    local project=$1
    shift
    echo "[BUILD] $project: ./gradlew $*"
    (cd "$REPO_DIR/$project" && ./gradlew --no-daemon --console=plain "$@")
}

run_gradle CA1/part2 bootJar
run_gradle CA1/part1 packageApp

echo "[INFO] Build finished."
