#!/bin/bash
# =============================================================================
# provisioning/base.sh - COGSI CA2 / Part 2
# -----------------------------------------------------------------------------
# Common provisioning applied to every machine:
#   - tools used by the other scripts and by the connectivity tests
#   - /etc/hosts entries, so the machines reach each other by hostname
#
# Environment (set by the Vagrantfile):
#   HOSTS_ENTRIES   one "<address> <hostname>" line per machine
#
# Idempotence: installed packages are skipped and the hosts block is replaced
# as a whole between two markers instead of being appended.
# =============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
# Keep needrestart from printing its report after every apt transaction.
export NEEDRESTART_SUSPEND=1

HOSTS_ENTRIES="${HOSTS_ENTRIES:?HOSTS_ENTRIES is required}"
PACKAGES=(curl netcat-openbsd ufw)

missing=()
for package in "${PACKAGES[@]}"; do
    if dpkg -s "$package" >/dev/null 2>&1; then
        echo "[OK] $package is already installed."
    else
        echo "[MISSING] $package"
        missing+=("$package")
    fi
done

if [ "${#missing[@]}" -gt 0 ]; then
    echo "[INSTALL] Installing: ${missing[*]}"
    apt-get update -qq
    apt-get install -y -qq -o Dpkg::Use-Pty=0 "${missing[@]}" >/dev/null
fi

# -----------------------------------------------------------------------------
# Hostname resolution
# -----------------------------------------------------------------------------
BEGIN="# BEGIN cogsi-ca2"
END="# END cogsi-ca2"

desired=$(printf '%s\n%s\n%s' "$BEGIN" "$HOSTS_ENTRIES" "$END")
current=$(sed -n "/^$BEGIN\$/,/^$END\$/p" /etc/hosts)

if [ "$current" = "$desired" ]; then
    echo "[OK] /etc/hosts already lists the machines."
else
    sed -i "/^$BEGIN\$/,/^$END\$/d" /etc/hosts
    printf '%s\n' "$desired" >>/etc/hosts
    echo "[CONFIG] /etc/hosts updated:"
    printf '%s\n' "$HOSTS_ENTRIES" | sed 's/^/         /'
fi
