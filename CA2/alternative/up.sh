#!/bin/bash
# =============================================================================
# up.sh - COGSI CA2 / Alternative (Multipass + cloud-init)
# -----------------------------------------------------------------------------
# Creates the three-tier Bookstore environment of Part 2 without Vagrant:
#
#   host --SSH tunnel--> proxy (Nginx) --8080--> app (Spring Boot) --9092--> db (H2)
#
# Multipass creates the instances (CPU, memory, disk, network) and cloud-init
# provisions each one on its first boot from the files in cloud-init/.
#
# Directory structure:
#   .
#   ├── up.sh           creates what is missing (this script)
#   ├── tunnel.sh       publishes the proxy on a host port through SSH
#   ├── down.sh         deletes the instances
#   ├── common.sh       settings shared by the scripts
#   ├── cloud-init/     one declarative definition per instance
#   └── keys/           SSH key pairs generated per instance (not versioned)
#
# Idempotence: an instance that already exists is not launched again (it is
# started if it was stopped) and an existing key pair is reused. cloud-init
# runs only on the first boot, so a changed definition is applied by deleting
# and recreating the instance (./down.sh <role>; ./up.sh).
#
# Usage: ./up.sh           (see common.sh for the environment variables)
# =============================================================================

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
cd "$SCRIPT_DIR"

# Prints the cloud-init definition of a role with its placeholders replaced.
render() {
    local role=$1 content name
    local -A values=(
        [PUBLIC_KEY]="$(cat "keys/${role}_ed25519.pub")"
        [MAC]="${MAC[$role]}" [IP]="${IP[$role]}"
        [DB_IP]="${IP[db]}" [APP_IP]="${IP[app]}" [PROXY_IP]="${IP[proxy]}"
        [H2_PORT]="$H2_PORT" [H2_VERSION]="$H2_VERSION" [H2_SHA1]="$H2_SHA1"
        [APP_PORT]="$APP_PORT" [DB_USER]="$DB_USER" [DB_PASSWORD]="$DB_PASSWORD"
        [REPO_URL]="$REPO_URL" [REPO_BRANCH]="$REPO_BRANCH"
    )

    content=$(<"cloud-init/$role.yaml")
    for name in "${!values[@]}"; do
        content=${content//"@@${name}@@"/"${values[$name]}"}
    done
    printf '%s\n' "$content"
}

echo "================================================="
echo "Creating the Bookstore environment with Multipass"
echo "================================================="

mkdir -p keys
for role in "${ROLES[@]}"; do
    name=$(instance_name "$role")

    # One ed25519 key pair per instance, generated once and reused.
    if [ -f "keys/${role}_ed25519" ]; then
        echo "[OK] Key pair of $role already exists."
    else
        ssh-keygen -q -t ed25519 -N "" -C "cogsi-ca2-alt-$role" -f "keys/${role}_ed25519"
        echo "[CONFIG] Key pair generated: keys/${role}_ed25519"
    fi

    state=$(instance_state "$role")
    case "$state" in
    Running)
        echo "[OK] Instance $name already exists and is running."
        ;;
    "")
        echo "[LAUNCH] $name: ${CPUS[$role]} CPU, ${MEMORY[$role]} memory, ${DISK[$role]} disk, ${IP[$role]}"
        render "$role" | "$MULTIPASS" launch "$IMAGE" \
            --name "$name" \
            --cpus "${CPUS[$role]}" --memory "${MEMORY[$role]}" --disk "${DISK[$role]}" \
            --network "name=$BRIDGE,mode=manual,mac=${MAC[$role]}" \
            --timeout "$LAUNCH_TIMEOUT" \
            --cloud-init - >/dev/null
        # Multipass waits for cloud-init; ask it whether every step succeeded.
        result=$(in_instance "$role" cloud-init status --long || true)
        if grep -q '^status: done' <<<"$result" && ! grep -q 'degraded' <<<"$result"; then
            echo "[READY] $name provisioned by cloud-init without errors."
        else
            echo "[ERROR] cloud-init reported a problem on $name:" >&2
            echo "$result" >&2
            exit 1
        fi
        ;;
    *)
        echo "[START] Instance $name exists in state $state - starting it."
        mp start "$name"
        ;;
    esac
done

echo "-------------------------------------------------"
mp list

# The Bookstore needs some time to start after the app instance is ready.
echo "[INFO] Waiting for the Bookstore to answer through the proxy..."
for ((elapsed = 0; elapsed < 300; elapsed += 5)); do
    status=$(in_instance proxy curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/actuator/health || true)
    if [ "$status" = "200" ]; then
        echo "[READY] GET http://proxy/actuator/health -> HTTP 200 (after ${elapsed}s)"
        echo "================================================="
        echo "Environment ready. Run ./tunnel.sh and open http://localhost:$TUNNEL_PORT/"
        echo "================================================="
        exit 0
    fi
    sleep 5
done

echo "[ERROR] The Bookstore did not answer through the proxy (last status: $status)." >&2
exit 1
