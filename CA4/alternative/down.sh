#!/usr/bin/env bash
# CA4 alternative - stop the Podman environment and remove its units.
# The volume (database) and the secret are kept unless --purge is given.
set -euo pipefail
UNIT_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd

systemctl --user stop cogsi-proxy.service cogsi-web.service cogsi-db.service 2>/dev/null || true
# The network and volume units are oneshot services that stay "active" after
# creating their object; they are stopped too, so that the next start creates
# the networks and the volume again if --purge deleted them.
systemctl --user stop cogsi-frontend-network.service cogsi-backend-network.service \
    cogsi-h2-data-volume.service 2>/dev/null || true
systemctl --user reset-failed 'cogsi-*' 2>/dev/null || true
rm -f "$UNIT_DIR"/cogsi-*.container "$UNIT_DIR"/cogsi-*.network "$UNIT_DIR"/cogsi-*.volume
systemctl --user daemon-reload
if [ "${1:-}" = --purge ]; then
    podman volume rm -f cogsi-h2-data >/dev/null 2>&1 || true
    podman secret rm cogsi-db-password >/dev/null 2>&1 || true
    podman network rm -f cogsi-frontend cogsi-backend >/dev/null 2>&1 || true
    rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/cogsi-ca4"
fi
