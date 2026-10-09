#!/bin/bash
# =============================================================================
# provisioning/base.sh - COGSI CA2 / Part 1
# -----------------------------------------------------------------------------
# Installs the dependencies of the two CA1 projects:
#   - git                       clones the group repository
#   - openjdk-21-jdk-headless   JDK 21, the toolchain required by both builds
#   - curl                      used by the service health check
#
# Gradle is not installed from apt: both projects ship the Gradle Wrapper, which
# downloads the exact version they were written for (9.4.0), while the Ubuntu
# package is several major versions behind. Maven is not needed because the
# Bookstore in the group repository is the Gradle conversion made in CA1.
#
# Idempotence: packages that are already installed are skipped, and the package
# index is only refreshed when something is actually missing.
# =============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
# Keep needrestart from printing its report after every apt transaction.
export NEEDRESTART_SUSPEND=1

PACKAGES=(git curl openjdk-21-jdk-headless)

echo "================================================="
echo "Installing project dependencies..."
echo "================================================="

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

echo "[INFO] $(git --version)"
echo "[INFO] $(java -version 2>&1 | head -n 1)"

echo "================================================="
echo "Project dependencies ready."
echo "================================================="
