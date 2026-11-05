# syntax=docker/dockerfile:1
# =============================================================================
# CA4 Part 1 - chat server, version 3: multi-stage build
# -----------------------------------------------------------------------------
# Stage "build" compiles the chat server with the JDK and the Gradle Wrapper;
# stage "runtime" starts again from a JRE image and copies only the result.
# The JDK, Gradle, the sources and the caches stay in the build stage.
#
# Build (from the repository root):
#   docker build -f CA4/part1/chat/v3/Dockerfile -t cogsi-chat:v3 CA1/part1
# Run:
#   docker run -d --name chat-v3 -p 59001:59001 cogsi-chat:v3
# =============================================================================

# ---------------------------------------------------------------------------
# Build stage
# ---------------------------------------------------------------------------
FROM eclipse-temurin:21.0.13_9-jdk AS build
WORKDIR /src

# Build files first: this layer, and the dependency download below, are reused
# from the cache as long as the build scripts do not change, even when the
# sources do.
COPY gradlew settings.gradle gradle.properties ./
COPY gradle/ gradle/
COPY app/build.gradle app/
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon --console=plain :app:dependencies --configuration runtimeClasspath > /dev/null

# Sources last, so that a code change rebuilds only from here.
COPY app/src/ app/src/
# The Gradle cache is a BuildKit cache mount: it speeds up later builds and is
# never written to an image layer.
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon --console=plain :app:packageApp \
 && mkdir -p /out \
 && cp app/build/libs/chat-server-*.jar /out/chat-server.jar \
 && cp -r app/build/libs/lib /out/lib

# ---------------------------------------------------------------------------
# Runtime stage
# ---------------------------------------------------------------------------
FROM eclipse-temurin:21.0.13_9-jre-alpine AS runtime

# Dedicated system user, without a home or a login shell. A fixed numeric UID
# lets a runtime check that the image is not root without reading
# /etc/passwd (e.g. Kubernetes runAsNonRoot).
RUN addgroup -S -g 10001 chat \
 && adduser -S -D -H -u 10001 -G chat -s /sbin/nologin chat

# The files keep the default owner, root, and mode 0644: the server can read
# its code but cannot change it.
COPY --from=build /out/ /opt/chat/

# Everything from here on, including the entry point, runs as the user.
USER 10001:10001

EXPOSE 59001

ENTRYPOINT ["java", "-cp", "/opt/chat/chat-server.jar:/opt/chat/lib/*", "org.example.ChatServerApp"]
CMD ["59001"]
