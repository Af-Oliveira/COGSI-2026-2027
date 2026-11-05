# CA4 - Containerization with Docker

Technical report for the fourth class assignment (CA4) of Configuracao e
Gestao de Sistemas (COGSI), Mestrado em Engenharia Informatica, Instituto
Superior de Engenharia do Porto.

- Topic: containers with Docker.
- Group repository: `Af-Oliveira/COGSI-2026-2027`.
- Milestone tags: `ca4-part1` and `ca4-part2`.
- Applications: the chat server of CA1 Part 1 (`CA1/part1`) and the Gradle
  version of the Bookstore Spring Boot application (`CA1/part2`).

This report follows a tutorial style: each requirement of the assignment is
quoted before the steps that implement it, the commands, the output they
produced and the explanation. Executing the instructions in order reproduces
the assignment. Every command is run from the root of the repository unless
stated otherwise.

---

## Table of contents

1. [Overview](#1-overview)
2. [Environment and prerequisites](#2-environment-and-prerequisites)
3. [Repository layout](#3-repository-layout)
4. [Part 1 - One image per CA1 application](#4-part-1---one-image-per-ca1-application)
5. [Part 2 - proxy, web and db with Docker Compose](#5-part-2---proxy-web-and-db-with-docker-compose)
6. [Alternative solution - analysis and design](#6-alternative-solution---analysis-and-design)
7. [Alternative solution - implementation](#7-alternative-solution---implementation)
8. [Operative guidelines and team work](#8-operative-guidelines-and-team-work)
9. [References](#9-references)

---

## 1. Overview

CA1 produced two Java applications built with Gradle, CA2 ran them in
virtual machines created by Vagrant and CA3 configured those machines with
Ansible. CA4 packages the same applications in containers:

- **Part 1** builds one image for the chat server and one for the Bookstore,
  each in three ways (source cloned and built inside the image, JAR built on
  the host, multi-stage build), and compares the results.
- **Part 2** rebuilds the three-tier environment of CA2 Part 2 (`proxy`,
  `web`, `db`) with Docker Compose.
- The **alternative** implements the same goals with Podman.

---

## 2. Environment and prerequisites

| Component | Version | Notes |
| --- | --- | --- |
| Host | Debian GNU/Linux 13 (trixie), kernel 6.12, x86-64 | 12 CPUs, 16 GB RAM |
| Docker Engine | 29.9.2 (API 1.56) | containerd 2.4.2 image store |
| Docker Buildx | 0.38.1 | BuildKit: cache mounts, Dockerfile-specific ignore files |
| Docker Compose | 5.6.1 | Part 2 |
| JDK on the host | OpenJDK 21.0.4 | only for version 2 of each image and for the chat client |
| Base images | `eclipse-temurin:21.0.13_9-jdk`, `eclipse-temurin:21.0.13_9-jre-alpine` | pinned to a JDK release, see [section 4.1](#41-build-strategies-and-base-images) |

> The images use the containerd image store, the default of Docker Engine 29.
> `docker image ls` shows two sizes: **disk usage** (the unpacked layers) and
> **content size** (the compressed layers, which is what is downloaded from a
> registry).

---

## 3. Repository layout

```text
CA4/
├── README.md                 this report
├── assets/                   screenshots used in the report
└── part1/
    ├── chat/                 chat server images (section 4.2)
    │   ├── v1/               Dockerfile + Dockerfile.dockerignore
    │   ├── v2/
    │   └── v3/
    └── bookstore/            Bookstore images (section 4.3)
        ├── v1/
        ├── v2/
        └── v3/
```

The applications are not copied into `CA4/`: versions 2 and 3 use `CA1/part1`
and `CA1/part2` as their build context, and version 1 clones them from the
group repository.

---

## 4. Part 1 - One image per CA1 application

> The goal of the Part 1 of this assignment is to gain hands-on experience
> with Docker by creating separate images and containers for each CA1
> application [...] You should create a Docker image (i.e., by using a
> Dockerfile) to execute the server. You should be able to run the server in a
> container and connect to it using the client running on your host computer

### 4.1. Build strategies and base images

> Create three versions of your solution: Version 1 - Build the application
> entirely inside the Docker image using source code cloned during image
> creation. Version 2 - Build the server on the host machine and copy the
> resulting JAR file into the Docker image. Version 3 - Implement a
> multi-stage build to separate the build and runtime stages

Each application has one directory per version, with a `Dockerfile` and its
ignore file:

| Version | Where the JAR is built | Build context | Base image of the final image |
| --- | --- | --- | --- |
| `v1` | inside the image, from a `git clone` | the empty `v1/` directory | `eclipse-temurin:21.0.13_9-jdk` (Ubuntu) |
| `v2` | on the host, with the Gradle Wrapper | the CA1 project | `eclipse-temurin:21.0.13_9-jre-alpine` |
| `v3` | in a build stage of the same Dockerfile | the CA1 project | `eclipse-temurin:21.0.13_9-jre-alpine` |

Choices common to every image:

- **Eclipse Temurin.** The official OpenJDK build of the Adoptium project,
  available as JDK and JRE, on Ubuntu and on Alpine. Version 1 needs the JDK
  (it compiles); versions 2 and 3 only run a JAR and use the JRE.
- **Pinned tags.** `21.0.13_9` instead of `21`: a rebuild next month uses the
  same Java release, so the comparison is not affected by an upstream update.
- **Same runtime image in `v2` and `v3`.** Both final images start from the
  same JRE, so the comparison shows what each strategy adds on top of it.
- **Same Gradle task in every version.** The chat server uses `packageApp`,
  a task written in CA1 that produces the thin JAR and copies its runtime
  dependencies to `build/libs/lib`. The tests are not run in the images,
  so the three build times measure the same work.
- **Exec form for `ENTRYPOINT`.** `java` runs as PID 1, without a shell in
  between, and receives the `SIGTERM` sent by `docker stop`. The port is the
  `CMD`, so it can be replaced at `docker run` time.
- **Dockerfile-specific ignore files.** The three versions of an application
  share the same build context (the CA1 project) but need different files
  from it. BuildKit reads `<Dockerfile name>.dockerignore` next to the
  Dockerfile before the `.dockerignore` of the context, so each version has
  its own `Dockerfile.dockerignore` and nothing is added to the CA1 folders.

### 4.2. Chat server

The chat server (`org.example.ChatServerApp`) listens on the port given as its
only argument, `59001` in every image. The client is a Swing application that
runs on the host.

#### Version 1 - clone and build inside the image

[`part1/chat/v1/Dockerfile`](part1/chat/v1/Dockerfile):

```dockerfile
FROM eclipse-temurin:21.0.13_9-jdk

ARG REPO_URL=https://github.com/Af-Oliveira/COGSI-2026-2027.git
ARG REPO_REF=main

RUN apt-get update \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" /src

WORKDIR /src/CA1/part1
RUN ./gradlew --no-daemon --console=plain :app:packageApp

RUN mkdir -p /opt/chat \
 && cp app/build/libs/chat-server-*.jar /opt/chat/chat-server.jar \
 && cp -r app/build/libs/lib /opt/chat/lib

EXPOSE 59001
ENTRYPOINT ["java", "-cp", "/opt/chat/chat-server.jar:/opt/chat/lib/*", "org.example.ChatServerApp"]
CMD ["59001"]
```

- `git` is installed in the image only to clone, and `--no-install-recommends`
  plus the removal of the package lists keep that layer small.
- `--depth 1 --branch "${REPO_REF}"` downloads a single revision. `REPO_REF`
  accepts a branch or a tag, so the image can be rebuilt from a fixed
  revision (`--build-arg REPO_REF=ca4-part1`).
- The repository is public, so no credentials are needed. A private
  repository would need a BuildKit secret (`RUN --mount=type=secret`), never
  a token in a `--build-arg`, which is recorded in the image history.
- Docker caches the `git clone` layer by its instruction text, not by the
  content of the repository. A new commit is only picked up with
  `--no-cache` or a different `REPO_REF`.

```bash
docker build -t cogsi-chat:v1 CA4/part1/chat/v1
```

The context is the `v1/` directory itself, and its ignore file excludes
everything (`*`): the builder receives 0 bytes from the host.

#### Version 2 - JAR built on the host

```bash
(cd CA1/part1 && ./gradlew :app:packageApp)
docker build -f CA4/part1/chat/v2/Dockerfile -t cogsi-chat:v2 CA1/part1
```

```console
Generated application JAR: chat-server-1.0.jar
app/build/libs:
chat-server-1.0.jar
lib

app/build/libs/lib:
log4j-api-2.26.1.jar
log4j-core-2.26.1.jar
```

[`part1/chat/v2/Dockerfile`](part1/chat/v2/Dockerfile):

```dockerfile
FROM eclipse-temurin:21.0.13_9-jre-alpine

COPY app/build/libs/chat-server-*.jar /opt/chat/chat-server.jar
COPY app/build/libs/lib/ /opt/chat/lib/

EXPOSE 59001
ENTRYPOINT ["java", "-cp", "/opt/chat/chat-server.jar:/opt/chat/lib/*", "org.example.ChatServerApp"]
CMD ["59001"]
```

The context is `CA1/part1`, but the ignore file is an allow list: it
excludes everything and re-includes only the JAR and `lib/`.

```text
*
!app/build/libs/chat-server-*.jar
!app/build/libs/lib/
```

The JAR name contains the version (`chat-server-1.0.jar`). The wildcard in
`COPY` renames it to `chat-server.jar`, so the entry point does not change
when the version does. The image depends on the state of the host: a JAR
built with another JDK, or not rebuilt after a change, goes into the image
as it is.

#### Version 3 - multi-stage build

```bash
docker build -f CA4/part1/chat/v3/Dockerfile -t cogsi-chat:v3 CA1/part1
```

[`part1/chat/v3/Dockerfile`](part1/chat/v3/Dockerfile):

```dockerfile
FROM eclipse-temurin:21.0.13_9-jdk AS build
WORKDIR /src

COPY gradlew settings.gradle gradle.properties ./
COPY gradle/ gradle/
COPY app/build.gradle app/
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon --console=plain :app:dependencies --configuration runtimeClasspath > /dev/null

COPY app/src/ app/src/
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon --console=plain :app:packageApp \
 && mkdir -p /out \
 && cp app/build/libs/chat-server-*.jar /out/chat-server.jar \
 && cp -r app/build/libs/lib /out/lib

FROM eclipse-temurin:21.0.13_9-jre-alpine AS runtime
COPY --from=build /out/ /opt/chat/
EXPOSE 59001
ENTRYPOINT ["java", "-cp", "/opt/chat/chat-server.jar:/opt/chat/lib/*", "org.example.ChatServerApp"]
CMD ["59001"]
```

- **Two stages.** `build` has the JDK, the Gradle Wrapper and the sources;
  `runtime` starts again from the JRE and receives only `/out` (the JAR and
  its two dependencies). The final image has no compiler, no Gradle and no
  source code.
- **Order of the layers.** The build scripts are copied first and the
  dependencies are resolved before the sources are copied. A change to a
  `.java` file reuses the cached dependency layer and only recompiles.
- **Cache mount.** `--mount=type=cache,target=/root/.gradle` keeps the
  Gradle distribution and the dependency cache between builds, in the
  BuildKit cache and never in a layer.
- **Ignore file.** The sources are needed now, so it is a deny list: the
  build output and the Gradle caches of the host (`.gradle/`, `**/build/`)
  are excluded, together with IDE files and logs. Otherwise a local build on
  the host would change the context and invalidate the `COPY` layers, and the
  image could depend on files compiled outside the Dockerfile.

#### Running the three versions and connecting from the host

Each version runs in its own container, published on a different host port:

```bash
docker run -d --name chat-v1 -p 59001:59001 cogsi-chat:v1
docker run -d --name chat-v2 -p 59002:59001 cogsi-chat:v2
docker run -d --name chat-v3 -p 59003:59001 cogsi-chat:v3
docker ps --filter name=chat- --format '{{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
```

```console
chat-v3  cogsi-chat:v3  0.0.0.0:59003->59001/tcp, [::]:59003->59001/tcp  Up 3 seconds
chat-v2  cogsi-chat:v2  0.0.0.0:59002->59001/tcp, [::]:59002->59001/tcp  Up 3 seconds
chat-v1  cogsi-chat:v1  0.0.0.0:59001->59001/tcp, [::]:59001->59001/tcp  Up 3 seconds
```

The chat protocol is text over TCP (`SUBMITNAME`, `NAMEACCEPTED`, `MESSAGE`),
so each container can first be checked from the host with `nc`:

```bash
for port in 59001 59002 59003; do
  (sleep 1; echo alice; sleep 1; echo "hello from the host"; sleep 1; echo /quit) | timeout 6 nc localhost $port
done
```

```console
SUBMITNAME
NAMEACCEPTED alice
MESSAGE alice: hello from the host
```

(the same three lines for each port). Then the Swing client of CA1 runs on
the host, with the `runClient` task, against version 3:

```bash
cd CA1/part1
./gradlew runClient -PserverIP=localhost -PserverPort=59003
```

![The chat client on the host asks for a screen name after the server in chat-v3 sent SUBMITNAME](assets/part1-chat-client-name.png)

A second participant (`afonso`, connected with `nc`) and the Swing client
(`ricardo`) exchange messages through the server in the container:

![Messages between the Swing client and a second participant through chat-v3](assets/part1-chat-client-messages.png)

```console
$ docker logs chat-v3
The chat server is running...
10:10:17.832 [pool-1-thread-2] INFO  org.example.ChatServer.Handler - A new user has joined: afonso
10:10:57.373 [pool-1-thread-3] INFO  org.example.ChatServer.Handler - A new user has joined: ricardo
10:11:16.633 [pool-1-thread-2] INFO  org.example.ChatServer.Handler - afonso has left the chat
```

The published port (`-p 59003:59001`) is what makes the server reachable:
Docker forwards connections to port 59003 of the host to port 59001 of the
container. `EXPOSE` only documents the port in the image metadata.

### 4.3. Bookstore

The Bookstore (`CA1/part2`) is a Spring Boot 4.1 application. The Spring Boot
Gradle plugin's `bootJar` task produces an executable JAR (`bookstore-1.0.0.jar`)
with every dependency nested in `BOOT-INF/lib`, so it runs with `java -jar`.
In Part 1 it keeps the in-memory H2 database of CA1; Part 2 connects it to an
H2 server.

#### Version 1 - clone and build inside the image

[`part1/bookstore/v1/Dockerfile`](part1/bookstore/v1/Dockerfile) follows the
chat server's version 1: JDK image, `git` installed, shallow clone of
`REPO_REF`, then:

```dockerfile
WORKDIR /src/CA1/part2
RUN ./gradlew --no-daemon --console=plain bootJar \
 && mkdir -p /opt/bookstore \
 && cp build/libs/bookstore-*.jar /opt/bookstore/bookstore.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/opt/bookstore/bookstore.jar"]
```

`bootJar` builds only the executable JAR. `build` would also run the unit and
integration tests and produce the plain JAR, the Javadoc and the
distributions, none of which the container needs.

```bash
docker build -t cogsi-bookstore:v1 CA4/part1/bookstore/v1
```

#### Version 2 - JAR built on the host

```bash
(cd CA1/part2 && ./gradlew bootJar)
docker build -f CA4/part1/bookstore/v2/Dockerfile -t cogsi-bookstore:v2 CA1/part2
```

```dockerfile
FROM eclipse-temurin:21.0.13_9-jre-alpine
COPY build/libs/bookstore-*.jar /opt/bookstore/bookstore.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/opt/bookstore/bookstore.jar"]
```

`build/libs` on the host also holds `bookstore-1.0.0-plain.jar`, made by the
`jar` task during a full `build`. It matches `bookstore-*.jar` too, and a
`COPY` of two files to one destination file fails. The ignore file therefore
re-includes the executable JAR and excludes the plain one again:

```text
*
!build/libs/bookstore-*.jar
build/libs/*-plain.jar
```

#### Version 3 - multi-stage build with the Spring Boot layers

```bash
docker build -f CA4/part1/bookstore/v3/Dockerfile -t cogsi-bookstore:v3 CA1/part2
```

The build stage is the same as the chat server's (build scripts, dependency
resolution, then sources, with a Gradle cache mount), with one more step. An
executable JAR is a single file, so in version 2 the 56 MB of dependencies and
the 33 KB of application classes are one layer, sent again to the registry
and to every host after each code change. Spring Boot can split the JAR into
layers, ordered from the one that changes least to the one that changes most:

```dockerfile
WORKDIR /extracted
RUN java -Djarmode=tools -jar /tmp/bookstore.jar extract --layers --destination . \
 && ls

FROM eclipse-temurin:21.0.13_9-jre-alpine AS runtime
WORKDIR /opt/bookstore
COPY --from=build /extracted/dependencies/ ./
COPY --from=build /extracted/spring-boot-loader/ ./
COPY --from=build /extracted/snapshot-dependencies/ ./
COPY --from=build /extracted/application/ ./
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/opt/bookstore/bookstore.jar"]
```

```console
#17 [build 9/9] RUN java -Djarmode=tools -jar /tmp/bookstore.jar extract --layers --destination .  && ls
#17 0.739 application
#17 0.739 dependencies
#17 0.739 snapshot-dependencies
#17 0.739 spring-boot-loader
```

`extract` writes the 80 libraries to `lib/` and a thin `bookstore.jar` whose
manifest lists them in its `Class-Path`, so `java -jar` still works and there
is no unpacking of nested JARs at start-up. The ignore file excludes the build
output and caches of the host, as in the chat server, and also
`src/test/` and `src/integrationTest/`: the tests do not run in the image, so
editing a test does not rebuild it.

`docker history` shows the four layers. The application layer, the only one
a code change replaces, is 32.8 kB:

```console
$ docker history cogsi-bookstore:v3 --format '{{.Size}}\t{{.CreatedBy}}' | head -6
0B      ENTRYPOINT ["java" "-jar" "/opt/bookstore/bookstore.jar"]
0B      EXPOSE [8080/tcp]
32.8kB  COPY /extracted/application/ ./ # buildkit
4.1kB   COPY /extracted/snapshot-dependencies/ ./ # buildkit
4.1kB   COPY /extracted/spring-boot-loader/ ./ # buildkit
55.7MB  COPY /extracted/dependencies/ ./ # buildkit
```

> The first attempt used `ENTRYPOINT ["java", "-jar", "application.jar"]`, as
> in older Spring Boot examples, and the container stopped with
> `Error: Unable to access jarfile /opt/bookstore/application.jar`. In Spring
> Boot 4 the extracted JAR keeps the name of the source JAR, `bookstore.jar`.

#### Running the three versions and using the API from the host

Port 8081 is used by another service on this host, so the containers use
18081 to 18083:

```bash
docker run -d --name bookstore-v1 -p 18081:8080 cogsi-bookstore:v1
docker run -d --name bookstore-v2 -p 18082:8080 cogsi-bookstore:v2
docker run -d --name bookstore-v3 -p 18083:8080 cogsi-bookstore:v3
for port in 18081 18082 18083; do curl -s localhost:$port/actuator/health; echo; curl -s localhost:$port/books; echo; done
```

```console
{"groups":["liveness","readiness"],"status":"UP"}
[{"author":"Robert C. Martin","id":1,"price":30.0,"title":"Clean Code"},{"author":"Joshua Bloch","id":2,"price":40.0,"title":"Effective Java"}]
```

(the same two lines for each port). Writing through the API of version 3:

```console
$ curl -s -X POST localhost:18083/books -H 'Content-Type: application/json' \
    -d '{"title":"Docker Deep Dive","author":"Nigel Poulton","price":35.0}'
{"author":"Nigel Poulton","id":3,"price":35.0,"title":"Docker Deep Dive"}
$ curl -s localhost:18083/books/3
{"_links":{"self":{"href":"http://localhost:18083/books/3"},"books":{"href":"http://localhost:18083/books"}},"author":"Nigel Poulton","id":3,"price":35.0,"title":"Docker Deep Dive"}
```

The `self` link uses the host and port of the request (`localhost:18083`), not
the address of the container, because Spring HATEOAS builds it from the
`Host` header.
