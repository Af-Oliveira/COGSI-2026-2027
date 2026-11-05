# syntax=docker/dockerfile:1
# =============================================================================
# CA4 Part 1 - chat server, version 1: clone and build inside the image
# -----------------------------------------------------------------------------
# The image clones the group repository while it is being built and compiles
# the chat server with the Gradle Wrapper. Nothing is copied from the host:
# the build context is empty (see Dockerfile.dockerignore).
#
# Build:  docker build -t cogsi-chat:v1 CA4/part1/chat/v1
# Run:    docker run -d --name chat-v1 -p 59001:59001 cogsi-chat:v1
# =============================================================================

# JDK image: the compiler and the Gradle Wrapper need a full JDK.
FROM eclipse-temurin:21.0.13_9-jdk

# Repository and revision to build. REPO_REF accepts a branch or a tag, so a
# given image can be rebuilt from the same sources (e.g. --build-arg REPO_REF=ca4-part1).
ARG REPO_URL=https://github.com/Af-Oliveira/COGSI-2026-2027.git
ARG REPO_REF=main

# Git is needed only to clone, but it stays in the image (single stage).
RUN apt-get update \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*

# A shallow clone downloads only the requested revision, not the whole history.
RUN git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" /src

# packageApp (a CA1 task) builds the thin JAR and copies its runtime
# dependencies to build/libs/lib. The Gradle distribution and the dependency
# cache downloaded here stay in the image.
WORKDIR /src/CA1/part1
RUN ./gradlew --no-daemon --console=plain :app:packageApp

# Fixed paths for the entry point, whatever the version in the JAR name.
RUN mkdir -p /opt/chat \
 && cp app/build/libs/chat-server-*.jar /opt/chat/chat-server.jar \
 && cp -r app/build/libs/lib /opt/chat/lib

EXPOSE 59001

# Exec form: java is PID 1 and receives SIGTERM from docker stop.
# The JVM expands lib/* itself, no shell is needed. CMD holds the port, so it
# can be changed with "docker run ... cogsi-chat:v1 <port>".
ENTRYPOINT ["java", "-cp", "/opt/chat/chat-server.jar:/opt/chat/lib/*", "org.example.ChatServerApp"]
CMD ["59001"]
