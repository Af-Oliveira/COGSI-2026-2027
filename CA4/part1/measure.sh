#!/usr/bin/env bash
# =============================================================================
# CA4 Part 1 - measure the three versions of each image
# -----------------------------------------------------------------------------
# For the chat server and the Bookstore, and for each version (v1, v2, v3):
#   - cold build time: build cache emptied first, base images already pulled
#     (v2 also counts the Gradle build on the host, which is part of its build)
#   - size on disk and compressed (content) size
#   - layer count (filesystem layers) and history entries
#   - what the final image contains: JDK compiler, git, Gradle, sources, packages
#   - HIGH and CRITICAL vulnerabilities reported by Trivy
#
# Usage (from the repository root):  CA4/part1/measure.sh [--skip-build] [--skip-scan]
# Output: a Markdown table on stdout; build logs in /tmp/ca4-measure/.
# =============================================================================
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
LOG_DIR=/tmp/ca4-measure
mkdir -p "$LOG_DIR"

TRIVY_IMAGE=aquasec/trivy:0.76.1
SKIP_BUILD=false
SKIP_SCAN=false
for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=true ;;
        --skip-scan) SKIP_SCAN=true ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

# app name -> CA1 project directory and Gradle task used in every version
declare -A PROJECT=([chat]=CA1/part1 [bookstore]=CA1/part2)
declare -A TASK=([chat]=":app:packageApp" [bookstore]="bootJar")
declare -A SECONDS_TAKEN
# Build times are also written to a file, so --skip-build can print them later.
TIMES_FILE="$LOG_DIR/build-times"
if [ -f "$TIMES_FILE" ]; then
    while read -r key value; do SECONDS_TAKEN[$key]=$value; done <"$TIMES_FILE"
fi

# Runs "$@" with its output appended to the log file $1 and prints the elapsed
# seconds (one decimal place).
timed() {
    local log=$1 start end
    shift
    start=$(date +%s.%N)
    # Inside $(...) errexit is not inherited, so a failure is returned explicitly.
    "$@" >>"$log" 2>&1 || return $?
    end=$(date +%s.%N)
    awk -v s="$start" -v e="$end" 'BEGIN { printf "%.1f", e - s }'
}

build() {
    local app=$1 version=$2 dir="CA4/part1/$1/$2" log="$LOG_DIR/$1-$2.log"
    local image="cogsi-$app:$version"

    # Empty the BuildKit cache, including the Gradle cache mounts of v3, so
    # every version starts from the same state: only the base images are local.
    docker builder prune -af >/dev/null
    : >"$log"

    case "$version" in
        v1)
            SECONDS_TAKEN[$app-$version]=$(timed "$log" docker build --no-cache -t "$image" "$dir") ;;
        v2)
            local host_build docker_build
            # The host keeps its own Gradle cache (~/.gradle): the dependencies
            # are not downloaded again, as in the normal work of a developer.
            host_build=$(timed "$log" bash -c "cd ${PROJECT[$app]} && ./gradlew --no-daemon -q clean ${TASK[$app]}")
            docker_build=$(timed "$log" docker build --no-cache -f "$dir/Dockerfile" -t "$image" "${PROJECT[$app]}")
            SECONDS_TAKEN[$app-$version]="$host_build + $docker_build" ;;
        v3)
            SECONDS_TAKEN[$app-$version]=$(timed "$log" docker build --no-cache -f "$dir/Dockerfile" -t "$image" "${PROJECT[$app]}") ;;
    esac
}

# Prints "yes" or "no" depending on whether a path or command exists in the
# image. Run as root: as the non-root user of the v3 images, /root (mode 0700)
# could not be read and a test inside it would always say "no".
has() {
    local image=$1 test=$2
    if docker run --rm --user 0 --entrypoint sh "$image" -c "$test" >/dev/null 2>&1; then echo yes; else echo no; fi
}

packages() {
    docker run --rm --user 0 --entrypoint sh "$1" -c \
        'if command -v dpkg-query >/dev/null; then dpkg-query -W | wc -l; else apk info 2>/dev/null | wc -l; fi'
}

vulnerabilities() {
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
        "$TRIVY_IMAGE" image --quiet --scanners vuln --severity HIGH,CRITICAL --format json "$1" \
        | python3 -c 'import json, sys
results = json.load(sys.stdin).get("Results") or []
found = [v["Severity"] for r in results for v in (r.get("Vulnerabilities") or [])]
print(found.count("HIGH"), "/", found.count("CRITICAL"))'
}

if [ "$SKIP_BUILD" = false ]; then
    : >"$TIMES_FILE"
    for app in chat bookstore; do
        for version in v1 v2 v3; do
            echo "building cogsi-$app:$version ..." >&2
            build "$app" "$version"
            echo "$app-$version ${SECONDS_TAKEN[$app-$version]}" | tee -a "$TIMES_FILE" >&2
        done
    done
fi

echo "| Image | Build time (s) | Disk usage | Content size | Layers | History entries | JDK compiler | git | Gradle cache | Sources | OS packages | HIGH / CRITICAL CVEs |"
echo "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
for app in chat bookstore; do
    for version in v1 v2 v3; do
        image="cogsi-$app:$version"
        # "docker image ls" with the containerd store: IMAGE ID DISK-USAGE CONTENT-SIZE
        read -r disk content < <(docker image ls "$image" | awk 'NR == 2 { print $3, $4 }')
        layers=$(docker image inspect "$image" --format '{{len .RootFS.Layers}}')
        history=$(docker history -q "$image" | wc -l)
        javac=$(has "$image" 'command -v javac')
        git=$(has "$image" 'command -v git')
        gradle=$(has "$image" 'test -d /root/.gradle')
        sources=$(has "$image" 'test -d /src')
        pkgs=$(packages "$image")
        cves="-"
        [ "$SKIP_SCAN" = false ] && cves=$(vulnerabilities "$image")
        time_taken="${SECONDS_TAKEN[$app-$version]:--}"
        echo "| \`$image\` | $time_taken | $disk | $content | $layers | $history | $javac | $git | $gradle | $sources | $pkgs | $cves |"
    done
done
