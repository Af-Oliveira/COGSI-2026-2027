# syntax=docker/dockerfile:1
# =============================================================================
# CA4 Part 2 - proxy: Nginx reverse proxy, the only entry point
# -----------------------------------------------------------------------------
# The official image renders /etc/nginx/templates/*.template with envsubst
# when the container starts, so the listening port and the upstream come from
# the environment (see compose.yaml): NGINX_PORT, UPSTREAM_HOST,
# UPSTREAM_PORT, PROXY_READ_TIMEOUT.
# =============================================================================

FROM nginx:1.31.8-alpine

# Defaults, overridden by Compose. Only variables that are defined are
# substituted, so Nginx's own variables ($host, $remote_addr...) are kept.
ENV NGINX_PORT=80 \
    UPSTREAM_HOST=web \
    UPSTREAM_PORT=8080 \
    PROXY_READ_TIMEOUT=60s

COPY templates/default.conf.template /etc/nginx/templates/default.conf.template
