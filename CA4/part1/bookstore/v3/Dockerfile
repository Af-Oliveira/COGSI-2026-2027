# syntax=docker/dockerfile:1
# =============================================================================
# CA4 Part 1 - Bookstore, version 3: multi-stage build with Spring Boot layers
# -----------------------------------------------------------------------------
# Stage "build" produces the executable JAR and splits it into the layers
# defined by Spring Boot (dependencies, loader, snapshot dependencies,
# application). Stage "runtime" copies each one to its own image layer, from
# the one that changes least to the one that changes most.
#
# Build (from the repository root):
#   docker build -f CA4/part1/bookstore/v3/Dockerfile -t cogsi-bookstore:v3 CA1/part2
# Run:
#   docker run -d --name bookstore-v3 -p 8080:8080 cogsi-bookstore:v3
# =============================================================================

# ---------------------------------------------------------------------------
# Build stage
# ---------------------------------------------------------------------------
FROM eclipse-temurin:21.0.13_9-jdk AS build
WORKDIR /src

# Build scripts first, then the dependency download: reused while the build
# scripts do not change.
COPY gradlew settings.gradle build.gradle gradle.properties ./
COPY gradle/ gradle/
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon --console=plain dependencies --configuration runtimeClasspath > /dev/null

COPY src/main/ src/main/
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon --console=plain bootJar \
 && cp build/libs/bookstore-*.jar /tmp/bookstore.jar

# Spring Boot's jarmode "tools" writes one directory per layer, each with the
# files of that layer; the thin bookstore.jar (application layer) references
# the libraries in lib/ through the Class-Path of its manifest.
WORKDIR /extracted
RUN java -Djarmode=tools -jar /tmp/bookstore.jar extract --layers --destination . \
 && ls

# ---------------------------------------------------------------------------
# Runtime stage
# ---------------------------------------------------------------------------
FROM eclipse-temurin:21.0.13_9-jre-alpine AS runtime

# Dedicated system user, without a home or a login shell, with a fixed
# numeric UID (see the chat server's Dockerfile).
RUN addgroup -S -g 10001 bookstore \
 && adduser -S -D -H -u 10001 -G bookstore -s /sbin/nologin bookstore

WORKDIR /opt/bookstore

# Least to most frequently changed: a code change only replaces the last
# layer (a few hundred KB), the dependencies (tens of MB) are reused.
COPY --from=build /extracted/dependencies/ ./
COPY --from=build /extracted/spring-boot-loader/ ./
COPY --from=build /extracted/snapshot-dependencies/ ./
COPY --from=build /extracted/application/ ./

# The application files stay owned by root (read-only for the user). Tomcat
# writes only to /tmp, which is writable by every user.
USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/opt/bookstore/bookstore.jar"]
