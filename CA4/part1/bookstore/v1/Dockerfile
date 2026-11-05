# syntax=docker/dockerfile:1
# =============================================================================
# CA4 Part 1 - Bookstore, version 1: clone and build inside the image
# -----------------------------------------------------------------------------
# The image clones the group repository while it is being built and produces
# the Spring Boot executable JAR of CA1 Part 2 with the Gradle Wrapper.
# The build context is empty (see Dockerfile.dockerignore).
#
# Build:  docker build -t cogsi-bookstore:v1 CA4/part1/bookstore/v1
# Run:    docker run -d --name bookstore-v1 -p 8080:8080 cogsi-bookstore:v1
# =============================================================================

FROM eclipse-temurin:21.0.13_9-jdk

ARG REPO_URL=https://github.com/Af-Oliveira/COGSI-2026-2027.git
ARG REPO_REF=main

RUN apt-get update \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" /src

# bootJar builds only the executable JAR (dependencies nested in BOOT-INF/lib),
# without running the unit and integration tests.
WORKDIR /src/CA1/part2
RUN ./gradlew --no-daemon --console=plain bootJar \
 && mkdir -p /opt/bookstore \
 && cp build/libs/bookstore-*.jar /opt/bookstore/bookstore.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/opt/bookstore/bookstore.jar"]
