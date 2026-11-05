# syntax=docker/dockerfile:1
# =============================================================================
# CA4 Part 1 - Bookstore, version 2: JAR built on the host
# -----------------------------------------------------------------------------
# The executable JAR is built on the host with the Gradle Wrapper and copied
# into a JRE image.
#
# Build (from the repository root):
#   (cd CA1/part2 && ./gradlew bootJar)
#   docker build -f CA4/part1/bookstore/v2/Dockerfile -t cogsi-bookstore:v2 CA1/part2
# Run:
#   docker run -d --name bookstore-v2 -p 8080:8080 cogsi-bookstore:v2
# =============================================================================

FROM eclipse-temurin:21.0.13_9-jre-alpine

# The build context is CA1/part2. Dockerfile.dockerignore lets only the
# executable JAR through (not the -plain JAR produced by the jar task).
COPY build/libs/bookstore-*.jar /opt/bookstore/bookstore.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/opt/bookstore/bookstore.jar"]
