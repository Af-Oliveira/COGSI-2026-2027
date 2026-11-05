# syntax=docker/dockerfile:1
# =============================================================================
# CA4 Part 1 - chat server, version 2: JAR built on the host
# -----------------------------------------------------------------------------
# The chat server is compiled on the host with the CA1 packageApp task, and
# the image only receives the result: the thin JAR and its dependencies.
#
# Build (from the repository root):
#   (cd CA1/part1 && ./gradlew :app:packageApp)
#   docker build -f CA4/part1/chat/v2/Dockerfile -t cogsi-chat:v2 CA1/part1
# Run:
#   docker run -d --name chat-v2 -p 59001:59001 cogsi-chat:v2
# =============================================================================

# Only a Java runtime is needed to run a JAR: JRE on Alpine, the smallest
# Temurin variant.
FROM eclipse-temurin:21.0.13_9-jre-alpine

# The build context is CA1/part1. Dockerfile.dockerignore lets only
# app/build/libs through.
COPY app/build/libs/chat-server-*.jar /opt/chat/chat-server.jar
COPY app/build/libs/lib/ /opt/chat/lib/

EXPOSE 59001

ENTRYPOINT ["java", "-cp", "/opt/chat/chat-server.jar:/opt/chat/lib/*", "org.example.ChatServerApp"]
CMD ["59001"]
