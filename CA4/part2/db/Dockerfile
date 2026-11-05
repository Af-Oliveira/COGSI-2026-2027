# syntax=docker/dockerfile:1
# =============================================================================
# CA4 Part 2 - db: H2 database engine in server mode
# -----------------------------------------------------------------------------
# A JRE image with the H2 JAR, an entrypoint that creates the database on the
# first start and a health check that runs an SQL query over TCP.
# Configuration (environment, see compose.yaml): DB_NAME, DB_USER,
# DB_PASSWORD, H2_PORT, H2_DATA_DIR.
# =============================================================================

FROM eclipse-temurin:21.0.13_9-jre-alpine

# Dedicated system user and data directory. When an empty named volume is
# mounted on /var/lib/h2, Docker copies this directory into it with its owner,
# so the volume is writable by h2 and by nobody else. /opt/h2 is created here
# because ADD --chmod would also apply 0644 to a directory it creates, and
# the user could not enter it.
RUN addgroup -S -g 10001 h2 \
 && adduser -S -D -H -u 10001 -G h2 -h /var/lib/h2 -s /sbin/nologin h2 \
 && install -d -m 0750 -o h2 -g h2 /var/lib/h2 \
 && install -d -m 0755 /opt/h2

# Same H2 release as the JDBC driver in the Bookstore (Spring Boot 4.1 BOM).
# The SHA-256 was computed from the JAR whose SHA-1 matches the one published
# on Maven Central (686180ad...), the check used in CA2. BuildKit refuses the
# download if the content differs.
ARG H2_VERSION=2.4.240
ARG H2_SHA256=29b70e427cc1c40cdc376283adbb0cc62853073797bb5fe5761f81fe73d57ce0
ADD --chmod=0644 --checksum=sha256:${H2_SHA256} \
    https://repo1.maven.org/maven2/com/h2database/h2/${H2_VERSION}/h2-${H2_VERSION}.jar /opt/h2/h2.jar

COPY --chmod=0755 entrypoint.sh /usr/local/bin/h2-entrypoint
COPY --chmod=0755 healthcheck.sh /usr/local/bin/h2-healthcheck

ENV DB_NAME=bookstore \
    H2_PORT=9092 \
    H2_DATA_DIR=/var/lib/h2

USER 10001:10001
WORKDIR /var/lib/h2
EXPOSE 9092

ENTRYPOINT ["/usr/local/bin/h2-entrypoint"]
