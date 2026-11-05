#!/usr/bin/env bash
# =============================================================================
# CA4 Part 1 - tag and publish the six images to a registry
# -----------------------------------------------------------------------------
# Tags, per application (chat version from CA1/part1/gradle.properties,
# Bookstore version from CA1/part2/build.gradle):
#   <app>:<version>-v1|v2|v3   one per build strategy, never moved
#   <app>:v1|v2|v3             latest build of each strategy
#   <app>:<version>, latest    the recommended image (version 3)
#
# Usage (from the repository root, after building the six images as cogsi-<app>:v1..v3):
#   REGISTRY=localhost:5000 CA4/part1/publish.sh     # local registry
#   REGISTRY=docker.io      CA4/part1/publish.sh     # Docker Hub (after docker login)
# Environment: REGISTRY (default docker.io), NAMESPACE (default rmotafreitas),
#              DRY_RUN=1 to print the commands only.
# =============================================================================
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
REGISTRY=${REGISTRY:-docker.io}
NAMESPACE=${NAMESPACE:-rmotafreitas}

chat_version=$(sed -n 's/^appVersion=//p' CA1/part1/gradle.properties)
bookstore_version=$(sed -n "s/^version = '\(.*\)'/\1/p" CA1/part2/build.gradle)
declare -A VERSION=([chat]=$chat_version [bookstore]=$bookstore_version)

run() {
    echo "+ $*"
    [ "${DRY_RUN:-0}" = 1 ] || "$@"
}

for app in chat bookstore; do
    repository="$REGISTRY/$NAMESPACE/cogsi-$app"
    version=${VERSION[$app]}
    [ -n "$version" ] || { echo "no version found for $app" >&2; exit 1; }

    tags=()
    for variant in v1 v2 v3; do
        source="cogsi-$app:$variant"
        docker image inspect "$source" >/dev/null 2>&1 \
            || { echo "missing image $source - build it first (section 4)" >&2; exit 1; }
        for tag in "$version-$variant" "$variant"; do
            run docker tag "$source" "$repository:$tag"
            tags+=("$tag")
        done
    done
    for tag in "$version" latest; do
        run docker tag "cogsi-$app:v3" "$repository:$tag"
        tags+=("$tag")
    done

    for tag in "${tags[@]}"; do
        run docker push --quiet "$repository:$tag"
    done
done
