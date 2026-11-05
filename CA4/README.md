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
> `docker image ls` shows two sizes. **Content size** is the compressed
> layers, what a `docker pull` downloads. **Disk usage** is everything the
> image occupies on the host: the unpacked layers (the sizes that
> `docker history` lists) **plus** the compressed copy kept in the content
> store. For the JRE base image: 212 MB unpacked + 75.1 MB compressed =
> 287 MB of disk usage.

---

## 3. Repository layout

```text
CA4/
├── README.md                 this report
├── assets/                   screenshots used in the report
├── part1/
│   ├── chat/                 chat server images (section 4.2)
│   │   ├── v1/               Dockerfile + Dockerfile.dockerignore
│   │   ├── v2/
│   │   └── v3/
│   ├── bookstore/            Bookstore images (section 4.3)
│   │   ├── v1/
│   │   ├── v2/
│   │   └── v3/
│   ├── measure.sh            builds, inspects and scans the six images (section 4.4)
│   └── publish.sh            tags and pushes the six images to a registry (section 4.8)
└── part2/                    Docker Compose environment (section 5)
    ├── compose.yaml          services db, web and proxy, networks and volume
    ├── .env.example          template of the environment (.env is not versioned)
    ├── db/                   H2 server image: Dockerfile, entrypoint, health check
    └── proxy/                Nginx image: Dockerfile and configuration template
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
- **Dockerfile-specific ignore files.** Versions 2 and 3 of an application
  share the same build context (the CA1 project) but need different files
  from it, and version 1 needs none. When a file named
  `<Dockerfile name>.dockerignore` exists next to the Dockerfile, BuildKit
  uses it instead of the `.dockerignore` of the context, so each version has
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
everything (`*`): the builder receives an empty context (`transferring
context: 25B` in the build log, the size of the empty archive).

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
  are excluded, together with IDE files and logs, so that the image can never
  depend on files compiled outside the Dockerfile. Section 4.4 measures what
  this changes in practice.

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
(cd CA1/part1 && ./gradlew runClient -PserverIP=localhost -PserverPort=59003)
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

`bootJar` alone leaves only `bookstore-1.0.0.jar` in `build/libs`, but a
full `./gradlew build` (run in CA1, or by anyone who runs the tests) also
leaves `bookstore-1.0.0-plain.jar`, made by the `jar` task. It matches
`bookstore-*.jar` too, and a `COPY` of two files to one destination file
fails. The ignore file therefore re-includes the executable JAR and excludes
the plain one again, so the build works whatever was built before:

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

`extract` writes 80 libraries to `lib/` (the executable JAR nests 81; the
81st, `spring-boot-jarmode-tools`, only serves the extraction and is left
out) and a thin `bookstore.jar` whose
manifest lists them in its `Class-Path`, so `java -jar` still works and there
is no unpacking of nested JARs at start-up. The ignore file excludes the build
output and caches of the host, as in the chat server, and also
`src/test/` and `src/integrationTest/`, because the tests do not run in the
image.

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

### 4.4. Comparison of the three versions

> Compare: build time, image size, layer count, security surface, are build
> dependencies included in the final image?

[`part1/measure.sh`](part1/measure.sh) builds the six images and inspects
them:

```bash
CA4/part1/measure.sh            # builds, inspects and scans (about 10 minutes)
CA4/part1/measure.sh --skip-build  # inspects the existing images only
```

- **Build time** is a cold build: `docker builder prune -af` empties the
  BuildKit cache (including the Gradle cache mount of version 3) before each
  build, and `--no-cache` is used. The base images are already pulled, so
  the network only serves Gradle and its dependencies. Version 2 counts two
  steps: `./gradlew clean <task>` on the host and `docker build`.
- **Disk usage** is what the image occupies on the host: unpacked layers
  plus the compressed copy (section 2); **content size** is the compressed
  size, what a `docker pull` downloads.
- **Layers** counts the filesystem layers (`RootFS.Layers`); **history
  entries** also counts the instructions that only change metadata.
- **JDK compiler, git, Gradle cache, sources** are tested inside the image,
  as root so that the non-root images cannot hide `/root` (mode 0700):
  `command -v javac`, `command -v git`, `test -d /root/.gradle`,
  `test -d /src`. **OS packages** counts the `dpkg` or `apk` packages.
- **CVEs** are the HIGH and CRITICAL vulnerabilities found by
  [Trivy](https://trivy.dev) 0.76.1, run as a container with access to the
  Docker socket.

The table is the second complete run, made after the version 3 images
gained their non-root user (section 4.7). The first run, before that
change, gave the same sizes, packages and CVEs, one layer less for each
version 3 image, and these build times: chat 39.3 / 5.1 + 6.9 / 31.8 s,
Bookstore 65.0 / 6.4 + 5.9 / 55.0 s.

| Image | Build time (s) | Disk usage | Content size | Layers | History entries | JDK compiler | git | Gradle cache | Sources | OS packages | HIGH / CRITICAL CVEs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `cogsi-chat:v1` | 36.5 | 1.14GB | 395MB | 11 | 27 | yes | yes | yes | yes | 158 | 15 / 2 |
| `cogsi-chat:v2` | 5.2 + 5.4 | 291MB | 76.3MB | 7 | 16 | no | no | no | no | 73 | 3 / 0 |
| `cogsi-chat:v3` | 27.5 | 291MB | 76.3MB | 7 | 17 | no | no | no | no | 73 | 3 / 0 |
| `cogsi-bookstore:v1` | 71.1 | 1.55GB | 563MB | 10 | 25 | yes | yes | yes | yes | 158 | 30 / 14 |
| `cogsi-bookstore:v2` | 5.9 + 7.3 | 393MB | 125MB | 6 | 14 | no | no | no | no | 73 | 8 / 4 |
| `cogsi-bookstore:v3` | 149.3 ¹ | 392MB | 124MB | 11 | 20 | no | no | no | no | 73 | 8 / 4 |

¹ 115.0 s of it was the dependency download (55.0 s for the whole build in
the first run); see the build-time paragraph.

**Build time.** Version 2 is the fastest by far (11 to 13 s) because the
host already has the Gradle distribution and every dependency in
`~/.gradle`: its `docker build` only copies files. Versions 1 and 3
download Gradle 9.4 (about 130 MB) and the dependencies on every cold build,
so their time is mostly network time and varies between runs. For the chat
server, version 3 was faster than version 1 in both runs (27.5 against
36.5 s): it does not install `git` with `apt` nor clone the repository. For
the Bookstore, version 3 took 55.0 s in the first run and 149.3 s in the
second, against 65.0 and 71.1 s for version 1. The build log shows where
the second run went: the step that only downloads the dependencies
(`gradlew dependencies`) took 115.0 s on its own, against 22.7 s for the
compilation. A cold build of versions 1 and 3 measures the network as much
as the build. The cold build is also the worst case for version 3. On a
rebuild, its layer order and cache mount pay off. After a one-line change
to `ChatServerApp.java`:

```console
#11 [build 5/8] COPY app/build.gradle app/
#11 CACHED
#13 [build 6/8] RUN --mount=type=cache,target=/root/.gradle ./gradlew ... :app:dependencies ...
#13 CACHED
#14 [build 7/8] COPY app/src/ app/src/
#15 [build 8/8] RUN --mount=type=cache,target=/root/.gradle ./gradlew ... :app:packageApp ...
#16 [runtime 2/2] COPY --from=build /out/ /opt/chat/
#16 CACHED
docker build ... 7.765 total
```

Only the sources were copied again and compiled, with Gradle and the
dependencies taken from the cache mount (7.8 s instead of about 30 s cold). The
change was a comment, so the compiled JAR came out byte-for-byte identical
(Gradle 9 builds reproducible archives), and BuildKit, which compares
content, reused even the runtime layer. Version 1 behaves the opposite way:
with a warm cache, every step including `git clone` is `CACHED`, so a new
commit in the repository is **not** picked up. Version 1 only sees new code
with `--no-cache` or a new `REPO_REF`.

**Image size.** Versions 2 and 3 are the same size (291 MB for the chat
server, 392-393 MB for the Bookstore): both are the JRE Alpine image (287 MB
of disk usage: 212 MB unpacked plus 75.1 MB compressed) plus the
application, counted twice in the same way (2.4 MB unpacked for the chat
server, 56 MB for the Bookstore).
Version 1 is four times bigger (1.14 GB and 1.55 GB) and downloads five times
more (395 MB against 76 MB compressed). It adds the full JDK on Ubuntu, `git`
and the build: the Gradle distribution and dependency cache, the sources and
the build output.

**Layer count.** Version 1 has more layers because each build step (`apt`,
`clone`, `gradlew`, copy) is a `RUN` that leaves a layer. Versions 2 and 3
add only a few layers to the 5 of the base image: 2 `COPY` layers for the
chat server's version 2 (JAR and `lib/`), and for its version 3 one `RUN`
that creates the unprivileged user (32.8 kB, section 4.7) plus one `COPY`
(`/out`). The Bookstore's version 3 has the most layers of the small images
(11: the user, the `WORKDIR` and four Spring Boot layers), on purpose: the
Spring Boot layers turn one 56 MB layer into four, so a code change only
replaces the 32.8 kB one. Fewer layers is not a goal in itself.
What matters is that the layers that change often are small and come last.

**Security surface and build dependencies.**

- *What is in the image.* Version 1 contains a compiler (`javac`), `git`,
  a shell with `apt`, 158 Ubuntu packages, the sources and Gradle with its
  caches. Anyone who gets a shell in the container can download, build and
  run code. Versions 2 and 3 have no compiler, `git`, Gradle or sources: a
  JRE, the application and 73 Alpine packages. A BusyBox shell and `apk`
  remain, part of the Alpine base.
- *Vulnerabilities.* Most of the CVEs of version 1 are not in the
  application. In the chat server image they are in the libraries of the
  Gradle distribution left in `/root/.gradle` (Jackson, Bouncy Castle,
  Guava, jsoup, plexus-utils) and in `apt`. The application never uses that
  code, but it is in the image, so it is reported, scanned and shipped.
  Versions 2 and 3 have the same findings: `libexpat` from Alpine (3 HIGH)
  for both applications, plus, for the Bookstore, the Tomcat (4 CRITICAL)
  and Jackson (5 HIGH) versions brought by Spring Boot 4.1.1. Those come
  from the application's dependencies, and only an upgrade of Spring Boot
  fixes them, whatever the build strategy.
- *Build arguments are recorded.* `docker history` of version 1 shows
  `RUN |2 REPO_URL=https://github.com/... REPO_REF=main` (section 4.5): a
  token passed as a build argument would be readable by anyone with the
  image.

**Are build dependencies included in the final image?** Yes in version 1
(JDK, `git`, Gradle, the dependency cache, the sources). No in version 2:
they are on the host, which in turn must have the right JDK, and the image
is only as reproducible as the host. No in version 3: they exist only in the
`build` stage, which is not part of the final image, and the build is the
same on any machine with Docker.

| Criterion | v1 clone | v2 host JAR | v3 multi-stage |
| --- | --- | --- | --- |
| Cold build | slow, network-bound | fastest (uses the host cache) | slow, network-bound |
| Rebuild after a code change | does not see the change | host build + copy | only the changed layers |
| Size (chat / Bookstore) | 1.14 / 1.55 GB | 291 / 393 MB | 291 / 392 MB |
| Build tools in the image | JDK, git, Gradle, sources | none | none |
| Toolchain needed on the host | none (Docker) | JDK 21 | none (Docker) |
| Reproducibility | depends on the remote at build time | depends on the host | the Dockerfile and the context |

Version 3 is the one used from here on: it has the small runtime image of
version 2 without needing a JDK on the host, and the build is described
entirely in the Dockerfile. Part 2 builds the `web` service from the
Bookstore's version 3 Dockerfile.

#### Ignore files

> Include and justify .dockerignore usage for each custom image

| Image | Context | Ignore file | Effect |
| --- | --- | --- | --- |
| `chat:v1`, `bookstore:v1` | the `v1/` directory | `*` | empty context: the sources come from the clone, no host file can reach the image |
| `chat:v2` | `CA1/part1` | allow list: `app/build/libs/chat-server-*.jar`, `app/build/libs/lib/` | only the artifacts are sent |
| `bookstore:v2` | `CA1/part2` | allow list: `build/libs/bookstore-*.jar`, minus `*-plain.jar` | only the executable JAR; avoids an ambiguous `COPY` |
| `chat:v3` | `CA1/part1` | deny list: `.gradle/`, `**/build/`, IDE files, logs | the host's build output can never reach the image |
| `bookstore:v3` | `CA1/part2` | deny list, plus `src/test/` and `src/integrationTest/` | as above, and the test sources are excluded too |

The size of the context sent to the builder is printed in each build
(`transferring context`): 2.38 MB for `chat:v2` (the JAR and `lib/`),
55.82 MB for `bookstore:v2` (the executable JAR), 80.68 kB and 97.89 kB for
the two version 3 images. To check the effect of an ignore file, the
Bookstore's version 3 was also built with a copy of its Dockerfile placed
elsewhere, so that no ignore file applied, after emptying the build cache.
The context was **97.89 kB in both cases**: BuildKit does not send the whole
directory, only the paths that the `COPY` instructions name (`gradlew`,
`gradle/`, `src/main/`, ...), so `build/` (54 MB) and `.gradle/` were never
sent. The deny lists of version 3 are still kept:

- they protect the image if a Dockerfile later uses a broad `COPY . .`,
  which is when the host's `build/` and `.gradle/` would end up in the
  image;
- other builders send the whole context: the legacy Docker builder, and
  Buildah, which Podman uses (section 7);
- they state which files the image depends on.

The allow lists of version 2 have a direct effect: they make the `COPY`
wildcard unambiguous (`*-plain.jar`), and the empty context of version 1
guarantees that nothing from the host is used.

### 4.5. Layers with `docker history`

> Use docker history to inspect each image's layers and the commands that
> created them. Observe how build choices affect image size and layer
> composition, and briefly explain the differences

```bash
docker history cogsi-chat:v1 --format '{{.Size}}\t{{.CreatedBy}}'
```

```console
0B      CMD ["59001"]
0B      ENTRYPOINT ["java" "-cp" "/opt/chat/chat-server.jar:/opt/chat/lib/*" ...
0B      EXPOSE [59001/tcp]
2.4MB   RUN |2 REPO_URL=https://github.com/Af-Oliveira/COGSI-2026-2027.git REPO_REF=main /bin/sh -c mkdir -p /opt/chat && cp ...
165MB   RUN |2 REPO_URL=... REPO_REF=main /bin/sh -c ./gradlew --no-daemon --console=plain :app:packageApp
4.1kB   WORKDIR /src/CA1/part1
4MB     RUN |2 REPO_URL=... REPO_REF=main /bin/sh -c git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" /src
78.5MB  RUN |2 REPO_URL=... REPO_REF=main /bin/sh -c apt-get update && apt-get install -y --no-install-recommends git ...
0B      ARG REPO_REF=main
0B      ARG REPO_URL=https://github.com/Af-Oliveira/COGSI-2026-2027.git
0B      CMD ["jshell"]
0B      ENTRYPOINT ["/__cacert_entrypoint.sh"]
12.3kB  COPY --chmod=755 entrypoint.sh /__cacert_entrypoint.sh
12.3kB  RUN /bin/sh -c set -eux; echo "Verifying install ..."
309MB   RUN /bin/sh -c set -eux; ARCH="$(dpkg --print-architecture)"; ...      <- the JDK
0B      ENV JAVA_VERSION=jdk-21.0.13+9
73.1MB  RUN /bin/sh -c set -eux; apt-get update; ...                          <- fonts, locales, certificates
...
117MB   umoci raw add-layer ...                                                <- Ubuntu 26.04 base
```

```bash
docker history cogsi-chat:v3 --format '{{.Size}}\t{{.CreatedBy}}'
```

```console
0B      CMD ["59001"]
0B      ENTRYPOINT ["java" "-cp" "/opt/chat/chat-server.jar:/opt/chat/lib/*" ...
0B      EXPOSE [59001/tcp]
0B      USER 10001:10001
2.4MB   COPY /out/ /opt/chat/ # buildkit
32.8kB  RUN /bin/sh -c addgroup -S -g 10001 chat && adduser -S -D -H -u 10001 -G chat -s /sbin/nologin chat
0B      ENTRYPOINT ["/__cacert_entrypoint.sh"]
12.3kB  COPY --chmod=755 entrypoint.sh /__cacert_entrypoint.sh
12.3kB  RUN /bin/sh -c set -eux; echo "Verifying install ..."
165MB   RUN /bin/sh -c set -eux; ARCH="$(apk --print-arch)"; ...              <- the JRE
0B      ENV JAVA_VERSION=jdk-21.0.13+9
37.9MB  RUN /bin/sh -c set -eux; apk add --no-cache ...                       <- fonts, locales, certificates
0B      ENV LANG=en_US.UTF-8 ...
0B      CMD ["/bin/sh"]
9.08MB  ADD alpine-minirootfs-3.24.3-x86_64.tar.gz /                         <- Alpine base
```

Reading the two histories from the bottom:

- **Base image.** Ubuntu (117 MB), its packages (73.1 MB) and the JDK
  (309 MB) in version 1, 499 MB unpacked, against Alpine (9 MB), its
  packages (37.9 MB) and the JRE (165 MB) in versions 2 and 3, 212 MB. The
  choice of base image alone explains 287 MB (499 - 212) of unpacked
  layers.
- **Build steps.** Version 1 adds a layer per build step: `git` (78.5 MB,
  with its dependencies), the clone (4 MB), and the Gradle build (165 MB: the
  Gradle distribution, the dependency cache and the build output). The
  application itself, 2.4 MB, is the last `RUN`. Deleting the caches in a
  later `RUN` would not help: the files would be hidden, but the earlier
  layers still contain them.
- **Version 3** has a single application layer, `COPY /out/ /opt/chat/`,
  and the 32.8 kB layer of the user it runs as (`/etc/passwd`,
  `/etc/group`, `/etc/shadow` updated by `adduser`). The `build` stage and
  its layers do not appear: only the final stage makes up the image.
- **Version 2** has two `COPY` layers (`chat-server-*.jar`, 24.6 kB, and
  `lib/`, 2.39 MB) and no user layer, since it runs as root (below).
- **Metadata.** `CMD`, `ENTRYPOINT`, `EXPOSE`, `USER`, `ENV` and `ARG` create
  history entries of 0 B and no filesystem layer, which is why there are
  more history entries than layers. The `ARG` values are recorded in the
  `RUN` lines that use them (`RUN |2 REPO_URL=... REPO_REF=main`).
- **The Bookstore** shows the same pattern (below): version 1 has the same
  `apt`, clone and Gradle layers, with a 402 MB Gradle layer (more
  dependencies than the chat server); version 2 a single 55.8 MB `COPY` of
  the executable JAR; version 3 the user and the four Spring Boot layers.

The other four images, from the top down to the last layer they add to their
base image (the base layers are the same as above):

```bash
for image in cogsi-chat:v2 cogsi-bookstore:v1 cogsi-bookstore:v2 cogsi-bookstore:v3; do
  echo "== $image"; docker history "$image" --format '{{.Size}}\t{{.CreatedBy}}'
done
```

```console
== cogsi-chat:v2
0B      CMD ["59001"]
0B      ENTRYPOINT ["java" "-cp" "/opt/chat/chat-server.jar:/opt/chat/lib/*" "org.example.ChatServerApp"]
0B      EXPOSE [59001/tcp]
2.39MB  COPY app/build/libs/lib/ /opt/chat/lib/ # buildkit
24.6kB  COPY app/build/libs/chat-server-*.jar /opt/chat/chat-server.jar # buildkit
...     (JRE Alpine base, as in cogsi-chat:v3)
== cogsi-bookstore:v1
0B      ENTRYPOINT ["java" "-jar" "/opt/bookstore/bookstore.jar"]
0B      EXPOSE [8080/tcp]
402MB   RUN |2 REPO_URL=... REPO_REF=main /bin/sh -c ./gradlew --no-daemon --console=plain bootJar && mkdir -p /opt/bookstore && cp ...
4.1kB   WORKDIR /src/CA1/part2
4.04MB  RUN |2 REPO_URL=... REPO_REF=main /bin/sh -c git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" /src
78.5MB  RUN |2 REPO_URL=... REPO_REF=main /bin/sh -c apt-get update && apt-get install -y --no-install-recommends git ...
0B      ARG REPO_REF=main
0B      ARG REPO_URL=https://github.com/Af-Oliveira/COGSI-2026-2027.git
...     (JDK Ubuntu base, as in cogsi-chat:v1)
== cogsi-bookstore:v2
0B      ENTRYPOINT ["java" "-jar" "/opt/bookstore/bookstore.jar"]
0B      EXPOSE [8080/tcp]
55.8MB  COPY build/libs/bookstore-*.jar /opt/bookstore/bookstore.jar # buildkit
...     (JRE Alpine base)
== cogsi-bookstore:v3
0B      ENTRYPOINT ["java" "-jar" "/opt/bookstore/bookstore.jar"]
0B      EXPOSE [8080/tcp]
0B      USER 10001:10001
32.8kB  COPY /extracted/application/ ./ # buildkit
4.1kB   COPY /extracted/snapshot-dependencies/ ./ # buildkit
4.1kB   COPY /extracted/spring-boot-loader/ ./ # buildkit
55.7MB  COPY /extracted/dependencies/ ./ # buildkit
12.3kB  WORKDIR /opt/bookstore
32.8kB  RUN /bin/sh -c addgroup -S -g 10001 bookstore && adduser -S -D -H -u 10001 -G bookstore -s /sbin/nologin bookstore
...     (JRE Alpine base)
```

In the Bookstore's version 1 the copy of the JAR is in the same `RUN` as the
build, so there is no separate application layer: the 402 MB layer holds the
Gradle distribution, the dependency cache, the build output and the copied
JAR together. Two of the Spring Boot layers of version 3 are 4.1 kB, the
size of an empty directory entry: the application has no snapshot
dependencies, and the loader is not needed because the extracted JAR runs
with `java -jar` and a `Class-Path` (section 4.3).

### 4.6. Resource usage

> Monitor your container's resource usage in real time. Observe CPU, memory,
> network, and disk I/O activity while the container runs

`docker stats` reads the cgroup counters of each container and refreshes
them every second: without `--no-stream` it keeps redrawing the table until
it is stopped, which is the real-time view; with `--no-stream` it prints one
sample. The Bookstore was started with limits, so that the `LIMIT` column
and the CPU quota are visible. The container of section 4.3 is replaced,
because a name can only be used once:

```bash
docker rm -f bookstore-v3
docker run -d --name bookstore-v3 --cpus 1.5 --memory 512m -p 18083:8080 cogsi-bookstore:v3
F='{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}'
docker stats --no-stream --format "table $F" bookstore-v3 chat-v3
```

```console
NAME           CPU %     MEM USAGE / LIMIT    MEM %     NET I/O           BLOCK I/O         PIDS
bookstore-v3   0.18%     211.6MiB / 512MiB    41.33%    4.34kB / 1.65kB   16.4kB / 49.2kB   29
chat-v3        0.14%     50.1MiB / 15.48GiB   0.32%     2.7kB / 126B      2.36MB / 73.7kB   19
```

#### Bookstore under load

Two terminals. In the first, the live view (stopped with `Ctrl+C`):

```bash
F='{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}'
docker stats --format "table $F" bookstore-v3
```

In the second, 6000 `GET /books` with 32 parallel clients, then 300
`POST /books`:

```bash
seq 1 6000 | xargs -P 32 -I{} curl -s -o /dev/null -w '%{http_code}\n' localhost:18083/books | sort | uniq -c
seq 1 300 | xargs -P 8 -I{} curl -s -o /dev/null -X POST localhost:18083/books \
  -H 'Content-Type: application/json' -d '{"title":"Load test","author":"COGSI","price":1.0}'
```

```console
   6000 200
```

The first terminal, one redraw per second (consecutive identical redraws
removed):

```console
NAME           CPU %     MEM USAGE / LIMIT   MEM %     NET I/O           BLOCK I/O         PIDS
bookstore-v3   0.00%     211.6MiB / 512MiB   41.33%    4.34kB / 1.65kB   16.4kB / 61.4kB   29
bookstore-v3   153.27%   227.4MiB / 512MiB   44.41%    76.8kB / 75.8kB   16.4kB / 61.4kB   56
bookstore-v3   152.24%   235.1MiB / 512MiB   45.91%    185kB / 194kB   16.4kB / 61.4kB   63
bookstore-v3   152.31%   233MiB / 512MiB     45.51%    286kB / 306kB   16.4kB / 61.4kB   63
bookstore-v3   150.84%   246MiB / 512MiB     48.05%    396kB / 428kB   16.4kB / 61.4kB   66
bookstore-v3   150.97%   247.6MiB / 512MiB   48.37%    509kB / 553kB   16.4kB / 73.7kB   66
bookstore-v3   151.87%   249.1MiB / 512MiB   48.65%    631kB / 686kB   16.4kB / 73.7kB   66
bookstore-v3   152.10%   250.9MiB / 512MiB   49.01%    758kB / 826kB   16.4kB / 73.7kB   66
```

and after the load:

```console
NAME           CPU %     MEM USAGE / LIMIT   MEM %     NET I/O           BLOCK I/O         PIDS
bookstore-v3   1.46%     263.7MiB / 512MiB   51.50%    3.11MB / 3.31MB   16.4kB / 98.3kB   67
```

#### Chat server under load

The same two terminals, with `docker stats --format "table $F" chat-v3` in
the first. In the second, 20 clients connect at the same time and each sends
50 messages, which the server broadcasts to every connected client:

```bash
for c in $(seq 1 20); do
  ( sleep 0.5; echo "user$c"; for m in $(seq 1 50); do echo "message $m from user$c"; done; sleep 4; echo /quit ) \
    | timeout 8 nc localhost 59003 >/dev/null &
done
wait
```

```console
NAME      CPU %     MEM USAGE / LIMIT    MEM %     NET I/O          BLOCK I/O        PIDS
chat-v3   0.00%     50.1MiB / 15.48GiB   0.32%     3.05kB / 126B    2.36MB / 98.3kB  19     <- idle
chat-v3   114.43%   75.3MiB / 15.48GiB   0.47%     799kB / 1.31MB   2.36MB / 98.3kB  50     <- the 1000 messages
chat-v3   0.15%     75.3MiB / 15.48GiB   0.47%     799kB / 1.31MB   2.36MB / 98.3kB  50
chat-v3   0.29%     63.21MiB / 15.48GiB  0.40%     799kB / 1.31MB   2.36MB / 98.3kB  50     <- 20 clients idle
chat-v3   2.10%     63.19MiB / 15.48GiB  0.40%     809kB / 1.33MB   2.36MB / 115kB   50     <- they leave
```

```console
$ docker top chat-v3 -o user,pid,nlwp,rss,args
USER     PID       NLWP   RSS     COMMAND
10001    3085627   50     83612   java -cp /opt/chat/chat-server.jar:/opt/chat/lib/* org.example.ChatServerApp 59001
```

#### What the samples show

- **CPU.** Under load the Bookstore stays between 150% and 153%, the quota
  set by `--cpus 1.5` (1.5 CPUs out of 12): the kernel throttles the
  container, it does not get more CPU because the host has idle cores. The
  chat server has no limit and uses 114% for the second in which the 1000
  messages arrive (each is written to 20 sockets), then goes back to almost
  nothing. A one-off sample can miss such a burst, which is why the live
  view matters.
- **Memory.** The Bookstore grows from 212 to 264 MiB under load (heap,
  Tomcat threads) and stays there afterwards: the JVM does not give memory
  back to the system right away. Without `--memory`, the limit shown is the
  whole host (15.48 GiB, `chat-v3`), and the JVM sizes its default maximum
  heap from it. With `--memory 512m` the JVM sees the container's limit:

  ```console
  $ docker exec bookstore-v3 java -XX:+PrintFlagsFinal -version | grep -E ' MaxHeapSize | MaxRAMPercentage '
     size_t MaxHeapSize          = 134217728     {product} {ergonomic}
     double MaxRAMPercentage     = 25.000000     {product} {default}
  $ docker exec chat-v3 java -XX:+PrintFlagsFinal -version | grep ' MaxHeapSize '
     size_t MaxHeapSize          = 4158652416    {product} {ergonomic}
  ```

  128 MiB is 25% of 512 MiB, and 3.9 GiB is 25% of the host. A quarter of
  the container is a small heap for a Spring Boot application, which is why
  Part 2 sets `-XX:MaxRAMPercentage=75`.
- **Network.** `NET I/O` is received / sent on the container's interface.
  The Bookstore sends slightly more than it receives (3.31 MB against
  3.11 MB). The chat server sends 1.31 MB: each line received is written to
  every connected client. Its received bytes include the clients' messages
  and the TCP acknowledgements of everything it sends.
- **Disk.** `BLOCK I/O` hardly moves: the Bookstore uses an in-memory H2
  database in Part 1 and only the logs are written. Part 2 moves the data
  to a volume.
- **PIDs.** The column counts threads, not processes. It grows with the
  load: Tomcat adds worker threads (29 to 67). The chat server goes from 19
  to 50: one handler thread per client (20) plus JVM compiler and garbage
  collector threads started under load. It stays at 50 after the clients
  leave because `ChatServer` runs its handlers in a fixed pool of up to 500
  threads (`Executors.newFixedThreadPool(500)`), which keeps idle threads.
  `docker top` shows the same, 50 threads (`NLWP`) in a single process.

### 4.7. Running as a non-root user

> Modify at least one Dockerfile to avoid running the application as the
> default root user by creating and using a dedicated unprivileged user
> through the USER instruction. Justify why running containers as non-root
> improves security, particularly regarding least privilege, host risk
> reduction, and container hardening

Without a `USER` instruction the process runs as `root`, the default of the
base image. The Dockerfiles in the repository already contain the change;
the version before it (commit `aff35b6`) can be built from Git to see the
difference:

```bash
git show aff35b6:CA4/part1/chat/v3/Dockerfile | docker build -f - -t cogsi-chat:v3-root CA1/part1
docker run -d --name chat-v3-root cogsi-chat:v3-root
```

```console
$ docker exec chat-v3-root id
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
$ docker exec chat-v3-root sh -c 'touch /opt/chat/chat-server.jar && echo "can modify the application"; head -c 40 /etc/shadow'
can modify the application
root:*::0:::::
bin:!::0:::::
daemon:!::0
$ ps -o user,pid,args -C java | grep ChatServerApp       # on the host
10001    3085627 java -cp /opt/chat/chat-server.jar:/opt/chat/lib/* org.example.ChatServerApp 59001
root     3146664 java -cp /opt/chat/chat-server.jar:/opt/chat/lib/* org.example.ChatServerApp 59001
```

On the host, the same program runs as UID 10001 in `chat-v3` (current
image) and as `root` in `chat-v3-root`. The root container is then removed
(`docker rm -f chat-v3-root`).

Both version 3 Dockerfiles now create a system user and switch to it in the
runtime stage ([chat](part1/chat/v3/Dockerfile),
[Bookstore](part1/bookstore/v3/Dockerfile)):

```dockerfile
FROM eclipse-temurin:21.0.13_9-jre-alpine AS runtime

RUN addgroup -S -g 10001 chat \
 && adduser -S -D -H -u 10001 -G chat -s /sbin/nologin chat

COPY --from=build /out/ /opt/chat/

USER 10001:10001
```

- `-S` creates a system account, `-D` without a password, `-H` without a
  home directory and `-s /sbin/nologin` without a login shell.
- The UID is fixed (10001, outside the range of the base image's users) and
  `USER` uses the number rather than the name: a platform can then check that
  the image is not root without reading `/etc/passwd` (Kubernetes
  `runAsNonRoot` requires a numeric UID).
- The application files are copied **before** `USER` and keep the owner
  `root` and mode 0644: the process reads its code but cannot change it.
- The only directory the Bookstore writes to is `/tmp` (Tomcat's work
  directory), which every user can write to.

After the change, in the containers of sections 4.2 and 4.3:

```console
$ docker exec chat-v3 id
uid=10001(chat) gid=10001(chat) groups=10001(chat)
$ docker exec chat-v3 sh -c 'touch /opt/chat/chat-server.jar'
touch: cannot touch '/opt/chat/chat-server.jar': Permission denied
$ docker exec chat-v3 sh -c 'head -c 40 /etc/shadow'
head: cannot open '/etc/shadow' for reading: Permission denied
$ docker exec chat-v3 ls -ln /opt/chat
-rw-r--r-- 1 0 0 9595 Nov  5 10:35 chat-server.jar
drwxr-xr-x 2 0 0 4096 Nov  5 10:35 lib
$ docker exec bookstore-v3 id
uid=10001(bookstore) gid=10001(bookstore) groups=10001(bookstore)
$ ps -o user,pid,args -C java       # on the host
10001    2946805 java -cp /opt/chat/chat-server.jar:/opt/chat/lib/* org.example.ChatServerApp 59001
10001    2946912 java -jar /opt/bookstore/bookstore.jar
$ docker image inspect cogsi-chat:v3 cogsi-bookstore:v3 --format '{{.Config.User}}'
10001:10001
10001:10001
```

Both applications still work: the chat protocol answers from the host and
`/actuator/health` is `UP` (section 4.6 was measured with these images).

Why it matters:

- **Least privilege.** The chat server needs to read its JAR and open a
  socket on port 59001, above 1024. Root gives it much more: writing to any
  file of the image (it could replace its own code, as shown above), reading
  `/etc/shadow`, installing packages with `apk`. As UID 10001, a bug that
  lets an attacker run commands only gets what the application needs.
- **Host risk reduction.** Docker does not remap users by default (no user
  namespace): `root` in the container is UID 0 on the host, as the first
  `ps` shows. The kernel is shared, so an escape through a kernel or runtime
  vulnerability, a mounted host directory or a mounted Docker socket would
  act as root on the host. As 10001, files created on a bind mount belong to
  an unprivileged UID, and an attacker who breaks out starts without root
  privileges. That reduces the impact; it is not a guarantee, because a
  kernel or runtime exploit can also escalate privileges.
- **Container hardening.** Non-root is one of several layers: Docker also
  drops most Linux capabilities and applies a seccomp profile by default.
  The image can go further at run time with `--read-only` (read-only root
  filesystem with a `tmpfs` on `/tmp`), `--cap-drop ALL` and
  `--security-opt no-new-privileges`. These options are cheap once the
  process no longer needs root.

Versions 1 and 2 were left as root on purpose, as the baseline of the
comparison: running as non-root does not depend on the build strategy and
would be the same three lines in any of them.

### 4.8. Tags and publishing

> Tag your images appropriately and publish them to Docker Hub

#### Tagging scheme

| Tag | Example | Points to | Moves? |
| --- | --- | --- | --- |
| `<version>-<strategy>` | `cogsi-chat:1.0-v1` | one build strategy of one application version | no |
| `<strategy>` | `cogsi-chat:v3` | the latest build of that strategy | yes |
| `<version>` | `cogsi-bookstore:1.0.0` | the recommended image (version 3) of that application version | no |
| `latest` | `cogsi-bookstore:latest` | the recommended image of the latest version | yes |

- The application version comes from the project itself (`appVersion=1.0`
  in `CA1/part1/gradle.properties`, `version = '1.0.0'` in
  `CA1/part2/build.gradle`), so the tag says which code is inside.
- The build strategy is part of the tag and not of the repository name: the
  three images run the same application, and one repository per
  application keeps them side by side (`docker pull rmotafreitas/cogsi-chat:1.0-v2`).
- `latest` is only a default for `docker pull` without a tag. Anything that
  must be reproducible (the Compose file of Part 2) uses a fixed tag, and the
  digest (`sha256:...`) is what identifies the content: `latest`, `1.0.0` and
  `1.0.0-v3` of the Bookstore have the same digest.

#### Publishing

[`part1/publish.sh`](part1/publish.sh) applies the scheme to the six images
built in sections 4.2 and 4.3 and pushes them to any registry, given by
`REGISTRY` and `NAMESPACE`. `DRY_RUN=1` prints the commands:

```console
$ DRY_RUN=1 REGISTRY=docker.io CA4/part1/publish.sh | head -6
+ docker tag cogsi-chat:v1 docker.io/rmotafreitas/cogsi-chat:1.0-v1
+ docker tag cogsi-chat:v1 docker.io/rmotafreitas/cogsi-chat:v1
+ docker tag cogsi-chat:v2 docker.io/rmotafreitas/cogsi-chat:1.0-v2
+ docker tag cogsi-chat:v2 docker.io/rmotafreitas/cogsi-chat:v2
+ docker tag cogsi-chat:v3 docker.io/rmotafreitas/cogsi-chat:1.0-v3
+ docker tag cogsi-chat:v3 docker.io/rmotafreitas/cogsi-chat:v3
```

> **Docker Hub is pending.** The machine used for this assignment is not
> logged in to the Docker Hub account used by the group (`rmotafreitas`,
> Ricardo's personal account), so the
> images were not pushed there. Publishing was verified instead with
> a local registry and a GitHub release (below). The Docker Hub push is the
> same script once the account is logged in:
>
> ```bash
> docker login -u rmotafreitas
> REGISTRY=docker.io CA4/part1/publish.sh
> ```

**Local registry.** `registry:3` is the reference implementation of the OCI
distribution API, the same protocol Docker Hub uses. It runs as a container,
with its storage in a volume:

```bash
docker run -d --name registry --restart unless-stopped -p 5000:5000 \
  -v registry-data:/var/lib/registry registry:3
REGISTRY=localhost:5000 CA4/part1/publish.sh
curl -s localhost:5000/v2/_catalog
curl -s localhost:5000/v2/rmotafreitas/cogsi-chat/tags/list
curl -s localhost:5000/v2/rmotafreitas/cogsi-bookstore/tags/list
```

```console
{"repositories":["rmotafreitas/cogsi-bookstore","rmotafreitas/cogsi-chat"]}
{"name":"rmotafreitas/cogsi-chat","tags":["1.0","1.0-v1","1.0-v2","1.0-v3","latest","v1","v2","v3"]}
{"name":"rmotafreitas/cogsi-bookstore","tags":["1.0.0","1.0.0-v1","1.0.0-v2","1.0.0-v3","latest","v1","v2","v3"]}
```

Docker accepts a registry on `localhost` over plain HTTP; any other host
would need TLS or an `insecure-registries` entry in the daemon
configuration. The 16 tags take 871 MB in the registry's volume: the layers
shared between images (the JRE base of versions 2 and 3, the JDK of
version 1) are stored once.

To check that the registry really serves the images, every local copy of the
Bookstore's version 2 was deleted and pulled back:

```bash
docker rmi cogsi-bookstore:v2 localhost:5000/rmotafreitas/cogsi-bookstore:1.0.0-v2 \
  localhost:5000/rmotafreitas/cogsi-bookstore:v2
docker pull localhost:5000/rmotafreitas/cogsi-bookstore:1.0.0-v2
docker run -d --name pulled-v2 -p 18090:8080 localhost:5000/rmotafreitas/cogsi-bookstore:1.0.0-v2
curl -s localhost:18090/actuator/health
```

```console
ae393e711df0: Pull complete
Digest: sha256:29da09e40243c7cf9ae894f78422ba9ea86d403b3ba62e5078312cd22c34835c
Status: Downloaded newer image for localhost:5000/rmotafreitas/cogsi-bookstore:1.0.0-v2
{"groups":["liveness","readiness"],"status":"UP"}
```

```console
$ docker buildx imagetools inspect localhost:5000/rmotafreitas/cogsi-bookstore:latest | head -3
Name:      localhost:5000/rmotafreitas/cogsi-bookstore:latest
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:89a08b03ebd8c5ca5cdd576e20781ebb53197e18b603afe57f5693a398ce7378
```

The pushed image is an OCI image index (`vnd.oci.image.index.v1+json`): the
containerd image store pushes the image together with its build
attestations, so a registry stores a list that points to the image for
`linux/amd64`.

**GitHub release.** The version 3 images of both applications are also
attached to the GitHub release of the tag `ca4-part1` (created in
section 4.9) as `docker save` archives, with their SHA-256 checksums. They
can be loaded without any registry:

```bash
gh release download ca4-part1 -R Af-Oliveira/COGSI-2026-2027 -p 'cogsi-*.tar.gz' -p SHA256SUMS
sha256sum -c SHA256SUMS
docker load -i cogsi-chat-1.0-v3.tar.gz
```

### 4.9. Tag `ca4-part1` and release

> At the end of this assignment mark your commit with the tag ca4-part1

On `main`, after the pull request that completes Part 1 was merged, the tag
marks the end of Part 1, and a GitHub release on it carries the version 3
images:

```bash
git switch main && git pull
git tag -a ca4-part1 -m "CA4 Part 1: Docker images for the CA1 applications"
git push origin ca4-part1

mkdir -p /tmp/ca4-release && cd /tmp/ca4-release
docker save cogsi-chat:v3 | gzip > cogsi-chat-1.0-v3.tar.gz
docker save cogsi-bookstore:v3 | gzip > cogsi-bookstore-1.0.0-v3.tar.gz
sha256sum cogsi-*.tar.gz > SHA256SUMS
gh release create ca4-part1 -R Af-Oliveira/COGSI-2026-2027 --verify-tag \
  --title "CA4 Part 1" \
  --notes "CA4 Part 1: version 3 images of the chat server and the Bookstore (docker load -i <file>)" \
  cogsi-*.tar.gz SHA256SUMS
```

---

## 5. Part 2 - proxy, web and db with Docker Compose

> The goal of Part 2 is to use Docker to create a containerized environment
> for running the Gradle version of the Bookstore Spring Boot application.
> You will implement a solution similar to Part 2 of CA2, but this time using
> Docker instead of Vagrant. Use Docker Compose to create three containers:
> proxy: reverse proxy / frontend entry point; web: hosts the Spring Boot
> application; db: runs the H2 database server

### 5.1. Design

```text
                 host :8080
                     │
             ┌───────▼────────┐  frontend (bridge)
             │ proxy (Nginx)  │──────────────┐
             └────────────────┘              │
                                     ┌───────▼────────┐
                                     │ web (Bookstore)│
                                     └───────┬────────┘
                       backend (bridge,      │ jdbc:h2:tcp://db:9092
                       internal: no route    │
                       outside the host)     │
                                     ┌───────▼────────┐      ┌──────────┐
                                     │ db (H2 server) │──────│ h2-data  │
                                     └────────────────┘      │ (volume) │
                                                             └──────────┘
```

| CA2 Part 2 (Vagrant) | CA4 Part 2 (Compose) |
| --- | --- |
| three VMs on a private network, fixed IPs (`192.168.56.20-22`) | three containers on two user-defined networks, found by name |
| `ufw`: H2 port open only to the app VM | `db` is only on the internal `backend` network; `proxy` is not on it |
| `wait-for-port` before starting the Bookstore | `depends_on: condition: service_healthy` |
| H2 data in a synced folder | H2 data in the named volume `h2-data` |
| `Vagrantfile` variables and provisioning scripts | `.env` and Compose environment variables |
| shell provisioning on every `vagrant up` | images built once (`docker compose build`), configured at start |

[`part2/compose.yaml`](part2/compose.yaml) describes the three services:

| Service | Image | Built from | Networks | Published |
| --- | --- | --- | --- | --- |
| `db` | `rmotafreitas/cogsi-ca4-h2:2.4.240` | [`part2/db/`](part2/db) | `backend` | no |
| `web` | `rmotafreitas/cogsi-ca4-bookstore:1.0.0` | the version 3 Dockerfile of Part 1, context `CA1/part2` | `backend`, `frontend` | no |
| `proxy` | `rmotafreitas/cogsi-ca4-proxy:1.0.0` | [`part2/proxy/`](part2/proxy) | `frontend` | `${PROXY_PUBLISHED_PORT}` |

### 5.2. Running the environment

```bash
cp CA4/part2/.env.example CA4/part2/.env      # then set DB_PASSWORD in it
docker compose -f CA4/part2/compose.yaml up -d --build --wait
docker compose -f CA4/part2/compose.yaml ps
```

Compose is run from the repository root. The `web` image is built with the
Dockerfile of Part 1, outside `CA4/part2`, and Compose 5 builds through
Buildx bake, which refuses to read files outside the current directory
unless allowed:

```console
$ cd CA4/part2 && docker compose build web
additional privileges requested: pass "--allow=fs.read=../part1/bookstore/v3/Dockerfile" to grant requested privileges
```

`docker compose` has no option to pass that permission. Run from the
root, the file is under the current directory and the build works. The
project directory is still `CA4/part2` (the directory of the Compose file),
so `.env` is read from there. Reusing the Part 1 Dockerfile keeps one
definition of the Bookstore image instead of a copy.

```console
NAME                IMAGE                                    SERVICE   STATUS                   PORTS
cogsi-ca4-db-1      rmotafreitas/cogsi-ca4-h2:2.4.240        db        Up 11 seconds (healthy)  9092/tcp
cogsi-ca4-proxy-1   rmotafreitas/cogsi-ca4-proxy:1.0.0       proxy     Up 2 seconds (healthy)   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
cogsi-ca4-web-1     rmotafreitas/cogsi-ca4-bookstore:1.0.0   web       Up 9 seconds (healthy)   8080/tcp
```

`--wait` returns only when every service is healthy. Only `proxy` publishes
a port; `9092/tcp` and `8080/tcp` are ports exposed on the container
networks, not on the host.

### 5.3. db - H2 in server mode

[`part2/db/Dockerfile`](part2/db/Dockerfile):

```dockerfile
FROM eclipse-temurin:21.0.13_9-jre-alpine

RUN addgroup -S -g 10001 h2 \
 && adduser -S -D -H -u 10001 -G h2 -h /var/lib/h2 -s /sbin/nologin h2 \
 && install -d -m 0750 -o h2 -g h2 /var/lib/h2 \
 && install -d -m 0755 /opt/h2

ARG H2_VERSION=2.4.240
ARG H2_SHA256=29b70e427cc1c40cdc376283adbb0cc62853073797bb5fe5761f81fe73d57ce0
ADD --chmod=0644 --checksum=sha256:${H2_SHA256} \
    https://repo1.maven.org/maven2/com/h2database/h2/${H2_VERSION}/h2-${H2_VERSION}.jar /opt/h2/h2.jar

COPY --chmod=0755 entrypoint.sh /usr/local/bin/h2-entrypoint
COPY --chmod=0755 healthcheck.sh /usr/local/bin/h2-healthcheck

ENV DB_NAME=bookstore H2_PORT=9092 H2_DATA_DIR=/var/lib/h2
USER 10001:10001
WORKDIR /var/lib/h2
EXPOSE 9092
ENTRYPOINT ["/usr/local/bin/h2-entrypoint"]
```

- **Same H2 as the driver.** 2.4.240 is the version of the H2 JDBC driver
  that Spring Boot 4.1.1 puts in the Bookstore. Client and server of the same
  release avoid protocol and file-format mismatches.
- **Verified download.** `ADD --checksum` makes BuildKit reject the JAR if
  its SHA-256 differs. The value was computed from the JAR whose SHA-1
  matches the one Maven Central publishes (`686180ad...`), the check used in
  CA2.
- **`/opt/h2` is created first.** The first version let `ADD --chmod=0644`
  create the directory. The container then stopped with
  `Error: Could not find or load main class org.h2.tools.Shell`: `--chmod`
  had also been applied to the directory (`drw-r--r--`), and without the
  execute bit the user `h2` could not enter it.
- **Unprivileged and owner of its data.** The server runs as UID 10001 and
  `/var/lib/h2` belongs to that user with mode 0750. When an empty named
  volume is mounted there for the first time, Docker copies the directory
  of the image into it, owner and mode included, so the volume is writable
  by the server and nobody else.

[`part2/db/entrypoint.sh`](part2/db/entrypoint.sh) creates the database on
the first start and then replaces itself with the server (`exec`, so the JVM
is PID 1 and receives `SIGTERM`):

```sh
if [ -f "$H2_DATA_DIR/$DB_NAME.mv.db" ]; then
    echo "[OK] Database $DB_NAME found in $H2_DATA_DIR (kept from the volume)."
else
    echo "[INIT] Creating database $DB_NAME in $H2_DATA_DIR, owned by $DB_USER."
    java -cp "$H2_JAR" org.h2.tools.Shell \
        -url "jdbc:h2:$H2_DATA_DIR/$DB_NAME" -user "$DB_USER" -password "$DB_PASSWORD" \
        -sql "SELECT 1" >/dev/null
fi
exec java ${JAVA_OPTS:-} -cp "$H2_JAR" org.h2.tools.Server \
    -tcp -tcpAllowOthers -tcpPort "$H2_PORT" -baseDir "$H2_DATA_DIR"
```

CA2 started H2 with `-ifNotExists`, which lets any client that reaches the
port create a database with credentials of its choice. Here the database is
created locally, once, and the user of that first connection
(`DB_USER`) becomes its administrator. The server then runs without
`-ifNotExists`:

```console
$ java -cp /opt/h2/h2.jar org.h2.tools.Shell -url jdbc:h2:tcp://db:9092/./other -user x -password y -sql "SELECT 1"
org.h2.jdbc.JdbcSQLNonTransientConnectionException: Database "/var/lib/h2/other" not found, either pre-create it or allow remote database creation (not recommended in secure environments) [90149-240]
$ java -cp /opt/h2/h2.jar org.h2.tools.Shell -url jdbc:h2:tcp://db:9092/./bookstore -user bookstore -password wrong -sql "SELECT 1"
org.h2.jdbc.JdbcSQLInvalidAuthorizationSpecException: Wrong user name or password [28000-240]
```

> The credentials are applied when the database is created. Changing
> `DB_PASSWORD` in `.env` afterwards does not change the password stored in
> the database: either change it with SQL (`ALTER USER ... SET PASSWORD`) or
> start from an empty volume (`docker compose down -v`).

#### Health check

> Configure a health check on the db container, so that the web service only
> starts after the database is available

[`part2/db/healthcheck.sh`](part2/db/healthcheck.sh) runs `SELECT 1` over TCP
with the application's credentials:

```sh
exec java -XX:TieredStopAtLevel=1 -cp /opt/h2/h2.jar org.h2.tools.Shell \
    -url "jdbc:h2:tcp://localhost:${H2_PORT}/./${DB_NAME}" \
    -user "$DB_USER" -password "$DB_PASSWORD" \
    -sql "SELECT 1" >/dev/null
```

```yaml
    healthcheck:
      test: ["CMD", "/usr/local/bin/h2-healthcheck"]
      interval: 15s
      timeout: 10s
      retries: 3
      start_period: 30s
      start_interval: 2s
```

- A TCP check (`nc -z db 9092`) only proves that the JVM listens. The query
  also proves that the database file opens and that the credentials of
  `web` are accepted, which is exactly what `web` needs.
- A Java exception ends the JVM with exit code 1, so a failed query is an
  unhealthy result; `-XX:TieredStopAtLevel=1` shortens the start of this
  short-lived JVM.
- `start_interval: 2s` probes every 2 seconds during the start period, so
  `db` is reported healthy about 2 seconds after it starts instead of after
  the first 15-second interval. After the start period, a probe every 15
  seconds, and 3 consecutive failures mark it unhealthy.

### 5.4. Persisting the database in a volume

> Use a Docker volume in the db container to persist the database file.
> Ensuring that data is stored outside the container's filesystem and can be
> retained and reused across container restarts

```yaml
services:
  db:
    volumes:
      - h2-data:/var/lib/h2
volumes:
  h2-data: {}
```

`h2-data` is a named volume managed by Docker
(`/var/lib/docker/volumes/cogsi-ca4_h2-data/_data` on the host), not a bind
mount: it does not depend on a path of the host, it is created with the
owner of `/var/lib/h2` in the image, and `docker compose down` keeps it
(only `down -v` deletes it).

The SQL runs inside `db`, with the credentials of its own environment (the
single quotes leave `$DB_USER` and `$DB_PASSWORD` to the container's shell,
so the password never has to be typed on the host):

```bash
C() { docker compose -f CA4/part2/compose.yaml "$@"; }
sql() { C exec -T db sh -c 'java -cp /opt/h2/h2.jar org.h2.tools.Shell \
  -url "jdbc:h2:tcp://localhost:$H2_PORT/./$DB_NAME" -user "$DB_USER" -password "$DB_PASSWORD" -sql "$1"' sh "$1"; }
sql "CREATE TABLE IF NOT EXISTS probe(id INT, note VARCHAR(40)); INSERT INTO probe VALUES (1, 'written before down')"
C down          # removes the containers and the networks
docker volume ls --filter name=cogsi-ca4
C up -d --wait
C logs db | tail -3
sql "SELECT * FROM probe"
```

```console
DRIVER    VOLUME NAME
local     cogsi-ca4_h2-data
db-1  | [OK] Database bookstore found in /var/lib/h2 (kept from the volume).
db-1  | [START] H2 TCP server on port 9092, base directory /var/lib/h2.
db-1  | TCP server running at tcp://172.24.0.2:9092 (others can connect)
ID | NOTE
1  | written before down
(1 row, 5 ms)
```

The containers were deleted and created again; the row and the database
survived in the volume, and the entrypoint found the database instead of
creating a new one. The same holds for data written through the API: the
book created in section 5.5 is still returned after every restart in the
following sections.

```console
$ docker exec cogsi-ca4-db-1 ls -ln /var/lib/h2
-rw-r--r-- 1 10001 10001 20480 Nov  5 10:41 bookstore.mv.db
```

> As in CA2 and CA3, the Bookstore inserts its sample data on every start,
> so the two sample books appear again after each restart with new ids. This
> is the behaviour of the application's `DataInitializer`, not data loss.

### 5.5. web - the Bookstore

```yaml
  web:
    image: ${IMAGE_NAMESPACE:-rmotafreitas}/cogsi-ca4-bookstore:${APP_VERSION:-1.0.0}
    build:
      context: ../../CA1/part2
      dockerfile: ../../CA4/part1/bookstore/v3/Dockerfile
    environment:
      SERVER_PORT: ${WEB_PORT:-8080}
      SPRING_DATASOURCE_URL: jdbc:h2:tcp://db:${H2_PORT:-9092}/./${DB_NAME:-bookstore}
      SPRING_DATASOURCE_USERNAME: ${DB_USER:?set DB_USER in .env}
      SPRING_DATASOURCE_PASSWORD: ${DB_PASSWORD:?set DB_PASSWORD in .env}
      SPRING_JPA_HIBERNATE_DDL_AUTO: ${JPA_DDL_AUTO:-update}
      SPRING_JPA_SHOW_SQL: ${JPA_SHOW_SQL:-false}
      SPRING_H2_CONSOLE_ENABLED: "false"
      JAVA_TOOL_OPTIONS: ${WEB_JAVA_OPTS:--XX:MaxRAMPercentage=75}
    depends_on:
      db:
        condition: service_healthy
    networks: [backend, frontend]
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:$${SERVER_PORT}/actuator/health | grep -q '\"status\":\"UP\"'"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 60s
      start_interval: 2s
    restart: unless-stopped
```

- **No change to the application.** Spring Boot reads its properties from
  environment variables with relaxed binding (`SPRING_DATASOURCE_URL` is
  `spring.datasource.url`), and they take precedence over the
  `application.properties` inside the JAR. CA2 wrote an
  `/etc/bookstore/application.properties` file; here the same settings are
  plain variables.
- **`depends_on: condition: service_healthy`.** Compose creates `web` only
  when the health check of `db` passes. Without the condition, `depends_on`
  only orders the creation of the containers, and the Bookstore could try
  to open its connection pool before H2 accepts connections.
- **Health check.** `/actuator/health` aggregates the health of the
  datasource, so it is `UP` only if the application is up **and** its
  connection to H2 works. `wget` is BusyBox's, already in the Alpine image.
  `$$` stops Compose from interpolating `SERVER_PORT` from `.env`, so
  the shell of the container expands it.
- **JVM sizing.** `-XX:MaxRAMPercentage=75` gives the heap 75% of the
  container's memory limit when one is set, instead of the JVM default of
  25% (section 4.6).
- **The image is the non-root version 3** of Part 1 (UID 10001).

```console
$ C logs web | grep -E 'Picked up|HikariPool-1 - Added'
web-1  | Picked up JAVA_TOOL_OPTIONS: -XX:MaxRAMPercentage=75
web-1  | ... HikariPool-1 - Added connection conn0: url=jdbc:h2:tcp://db:9092/./bookstore user=BOOKSTORE
$ curl -s -X POST localhost:8080/books -H 'Content-Type: application/json' \
    -d '{"title":"Persisted in H2","author":"COGSI","price":12.5}'
{"author":"COGSI","id":3,"price":12.5,"title":"Persisted in H2"}
```

#### Start order

Starting from nothing (`down` then `up -d --wait`):

```console
 Container cogsi-ca4-db-1 Started
 Container cogsi-ca4-db-1 Waiting
 Container cogsi-ca4-db-1 Healthy
 Container cogsi-ca4-web-1 Started
 Container cogsi-ca4-web-1 Waiting
 Container cogsi-ca4-web-1 Healthy
 Container cogsi-ca4-proxy-1 Started
 ...
 Container cogsi-ca4-proxy-1 Healthy
```

```console
$ for s in db web proxy; do echo "$s started $(docker inspect cogsi-ca4-$s-1 --format '{{.State.StartedAt}}' | cut -c12-23)"; done
db started 10:54:22.286
web started 10:54:24.918
proxy started 10:54:31.553
$ docker inspect cogsi-ca4-web-1 --format '{{json .State.Health}}'     # first probes, summarised
10:54:27.041 exit 1
10:54:29.077 exit 1
10:54:31.114 exit 0
```

`web` started 2.6 s after `db`, once the SQL check passed. Its first two
probes failed while Spring Boot was starting (the failures inside
`start_period` do not count towards `retries`), the third passed at
10:54:31.114, and `proxy` started 0.4 s later.

#### The health check follows the database

```console
$ C stop db
$ curl -s -w ' HTTP %{http_code}\n' localhost:8080/actuator/health
{"groups":["liveness","readiness"],"status":"DOWN"} HTTP 503
$ C ps --format '{{.Service}}\t{{.Status}}'
web     Up About a minute (unhealthy)
$ C start db
$ curl -s -w ' HTTP %{http_code}\n' localhost:8080/actuator/health
{"groups":["liveness","readiness"],"status":"UP"} HTTP 200
```

The connection pool reconnects by itself when `db` comes back. Docker
only reports `unhealthy`: a restart policy reacts to the process exiting,
not to the health status, so an unhealthy container is not restarted.
`depends_on` acts only when the environment starts.

### 5.6. proxy - Nginx

> proxy: reverse proxy / frontend entry point [...] Configure a health check
> on the web container, so that the proxy service only starts after the
> application is available

[`part2/proxy/Dockerfile`](part2/proxy/Dockerfile) adds a template to the
official image:

```dockerfile
FROM nginx:1.31.8-alpine
ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    NGINX_PORT=80 \
    UPSTREAM_HOST=web \
    UPSTREAM_PORT=8080 \
    PROXY_READ_TIMEOUT=60s
COPY templates/default.conf.template /etc/nginx/templates/default.conf.template
```

[`default.conf.template`](part2/proxy/templates/default.conf.template):

```nginx
resolver ${NGINX_LOCAL_RESOLVERS} valid=10s ipv6=off;

server {
    listen ${NGINX_PORT} default_server;
    server_name _;

    location = /nginx-health {
        access_log off;
        default_type text/plain;
        return 200 "ok\n";
    }

    location / {
        set $upstream http://${UPSTREAM_HOST}:${UPSTREAM_PORT};
        proxy_pass $upstream;

        proxy_set_header Host              $http_host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_read_timeout    ${PROXY_READ_TIMEOUT};
    }
}
```

- **Template rendered at start.** The entrypoint of the official image runs
  `envsubst` on `/etc/nginx/templates/*.template` and writes the result to
  `/etc/nginx/conf.d/`. Only variables that are defined in the environment
  are replaced, so Nginx's own variables (`$http_host`, `$remote_addr`) are
  left alone. One image serves any port or upstream.
- **Name resolved at request time.** With a literal `proxy_pass http://web:8080`,
  Nginx resolves `web` once, at start, and keeps that address. With a
  variable it asks the `resolver` at request time (cached 10 s), so it
  follows `web` if the container is recreated with another address. Tested
  by forcing `web` to a new address: removed, its old address taken by
  another container, then created again (`172.25.0.2` -> `172.25.0.4`). The
  proxy kept answering 200 without being restarted.
- **The resolver comes from `/etc/resolv.conf`.**
  `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` makes the entrypoint export the name
  servers of the container as `NGINX_LOCAL_RESOLVERS`. The first version
  had Docker's embedded DNS address, `127.0.0.11`, written in the template,
  and returned `502 Bad Gateway` under Podman, whose DNS server is the
  network gateway (section 7). The rendered configuration under Docker:

  ```console
  $ C exec -T proxy grep -E 'resolver|listen|upstream' /etc/nginx/conf.d/default.conf
  resolver 127.0.0.11 valid=10s ipv6=off;
      listen 80 default_server;
          set $upstream http://web:8080;
  ```

- **`Host $http_host`** passes the host and port the client used
  (`localhost:8080`), so the HATEOAS links point to the proxy, as in CA2.
- **`/nginx-health`** answers locally, without going to `web`, and is the
  proxy's health check.

```yaml
  proxy:
    image: ${IMAGE_NAMESPACE:-rmotafreitas}/cogsi-ca4-proxy:${PROXY_VERSION:-1.0.0}
    build:
      context: ./proxy
    environment:
      NGINX_PORT: ${PROXY_LISTEN_PORT:-80}
      UPSTREAM_HOST: ${PROXY_UPSTREAM_HOST:-web}
      UPSTREAM_PORT: ${WEB_PORT:-8080}
      PROXY_READ_TIMEOUT: ${PROXY_READ_TIMEOUT:-60s}
    ports:
      - "${PROXY_PUBLISHED_PORT:-8080}:${PROXY_LISTEN_PORT:-80}"
    depends_on:
      web:
        condition: service_healthy
    networks: [frontend]
```

```console
$ curl -s -i localhost:8080/books/3 | grep -E '^HTTP|^Server|^Content-Type'
HTTP/1.1 200
Server: nginx/1.31.8
Content-Type: application/hal+json
$ curl -s localhost:8080/books/3
{"_links":{"self":{"href":"http://localhost:8080/books/3"},"books":{"href":"http://localhost:8080/books"}},"author":"COGSI","id":3,"price":12.5,"title":"Persisted in H2"}
$ docker port cogsi-ca4-web-1 | wc -l
0
```

### 5.7. Name resolution and isolation

> Verify network connectivity between the services. Ensure containers can
> resolve each other's hostnames

On a user-defined network, Docker runs an embedded DNS server
(`127.0.0.11` in each container) that resolves the name of each service
(and of each container) to its address **on that network**. The default
`bridge` network has no such server, which is why Compose creates its own.

```bash
C exec -T web getent hosts db        # web is on backend and frontend
C exec -T web getent hosts proxy
C exec -T proxy getent hosts web
C exec -T proxy getent hosts db      # proxy is only on frontend
C exec -T db getent hosts web
C exec -T proxy sh -c 'nc -z -w2 web 8080 && echo "proxy -> web:8080 open"'
C exec -T web sh -c 'nc -z -w2 db 9092 && echo "web -> db:9092 open"'
C exec -T db sh -c 'wget -q -T 3 -O /dev/null https://repo1.maven.org || echo "db -> internet: blocked"'
for n in frontend backend; do docker network inspect cogsi-ca4_$n \
  --format '{{.Name}} internal={{.Internal}} {{range .Containers}}{{.Name}}={{.IPv4Address}} {{end}}'; done
```

```console
172.24.0.2        db  db
172.25.0.3        proxy  proxy
172.25.0.2        web  web
proxy: db not resolvable (exit 2)
172.24.0.3        web  web
proxy -> web:8080 open
web -> db:9092 open
wget: bad address 'repo1.maven.org'
db -> internet: blocked
cogsi-ca4_frontend internal=false cogsi-ca4-proxy-1=172.25.0.3/16 cogsi-ca4-web-1=172.25.0.2/16
cogsi-ca4_backend internal=true cogsi-ca4-db-1=172.24.0.2/16 cogsi-ca4-web-1=172.24.0.3/16
```

- `web` has one address on each network, and each peer sees the address on
  the network they share (`db` sees `web` as `172.24.0.3`, `proxy` as
  `172.25.0.2`).
- `proxy` cannot resolve `db` at all: they share no network. This replaces
  the `ufw` rule of CA2, and it is enforced by the topology rather than by a
  firewall rule inside a machine.
- `backend` is `internal: true`: it has no gateway to the outside, so
  `db` cannot even resolve an external name. The database has no reason to
  reach the internet, and a compromised `db` cannot use it to exfiltrate
  data. A side effect is that an internal network cannot publish ports,
  which is why `web` was attached to `frontend` from the start, before the
  proxy existed.

### 5.8. Configuration with environment variables

> Use Docker Compose environment variables to configure all services. E.g.:
> db: database credentials and storage settings; web: Spring application and
> database connectivity; proxy: externally exposed port and optionally proxy
> routing settings

Every value that may change between environments is a variable read from
`CA4/part2/.env` (not versioned, see [`.gitignore`](part2/.gitignore)), with
[`.env.example`](part2/.env.example) as the template:

| Service | Variable in `.env` | Becomes in the container | Default |
| --- | --- | --- | --- |
| all | `IMAGE_NAMESPACE`, `APP_VERSION`, `PROXY_VERSION`, `H2_VERSION` | image names and tags | `rmotafreitas`, `1.0.0`, `1.0.0`, `2.4.240` |
| db | `DB_NAME`, `DB_USER`, `DB_PASSWORD` | `DB_NAME`, `DB_USER`, `DB_PASSWORD` | `bookstore`, required, required |
| db | `H2_PORT`, `DB_JAVA_OPTS` | `H2_PORT`, `JAVA_OPTS`; storage `H2_DATA_DIR=/var/lib/h2` | `9092`, `-Xmx256m` |
| web | `WEB_PORT` | `SERVER_PORT` | `8080` |
| web | `DB_NAME`, `H2_PORT` | `SPRING_DATASOURCE_URL=jdbc:h2:tcp://db:<port>/./<name>` | |
| web | `DB_USER`, `DB_PASSWORD` | `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` | required |
| web | `JPA_DDL_AUTO`, `JPA_SHOW_SQL`, `WEB_JAVA_OPTS` | `SPRING_JPA_*`, `JAVA_TOOL_OPTIONS` | `update`, `false`, `-XX:MaxRAMPercentage=75` |
| proxy | `PROXY_PUBLISHED_PORT`, `PROXY_LISTEN_PORT` | host port, `NGINX_PORT` | `8080`, `80` |
| proxy | `PROXY_UPSTREAM_HOST`, `WEB_PORT`, `PROXY_READ_TIMEOUT` | `UPSTREAM_HOST`, `UPSTREAM_PORT`, `PROXY_READ_TIMEOUT` | `web`, `8080`, `60s` |

- **One source per value.** `DB_USER` and `DB_PASSWORD` configure both
  sides, the database and the datasource, so they cannot drift apart.
  `WEB_PORT` is both the port of the Bookstore and the upstream port of the
  proxy.
- **Required values fail early.** `${DB_PASSWORD:?...}` stops Compose before
  anything is created if the password is missing or empty, and the
  template leaves it empty on purpose. An empty value given in the shell
  (which takes precedence over `.env`, next point) shows it without touching
  the configured `.env`:

  ```console
  $ DB_PASSWORD='' docker compose -f CA4/part2/compose.yaml config --quiet
  error while interpolating services.db.environment.DB_PASSWORD: required variable DB_PASSWORD is missing a value: set DB_PASSWORD in .env
  error while interpolating services.web.environment.SPRING_DATASOURCE_PASSWORD: required variable DB_PASSWORD is missing a value: set DB_PASSWORD in .env
  ```

- **Variables of the shell override `.env`.** The proxy was moved to
  another host port and another listening port without editing any file:

  ```console
  $ PROXY_PUBLISHED_PORT=8088 PROXY_LISTEN_PORT=8000 docker compose -f CA4/part2/compose.yaml up -d --wait proxy
  $ docker compose -f CA4/part2/compose.yaml ps proxy --format '{{.Ports}}'
  80/tcp, 0.0.0.0:8088->8000/tcp, [::]:8088->8000/tcp
  $ docker compose -f CA4/part2/compose.yaml exec -T proxy grep listen /etc/nginx/conf.d/default.conf
      listen 8000 default_server;
  ```

- **`docker compose config`** prints the file with every variable
  replaced, which is how the result of the interpolation can be checked
  before starting anything.

> Environment variables are visible to anyone who can run `docker inspect`
> on the container. The assignment asks for variables, and `.env` is kept
> out of Git. For production, Compose `secrets:` mount the value as a file
> (`/run/secrets/...`) instead. The Podman implementation (section 7) uses
> Podman secrets.

### 5.9. Publishing the images

> Publish the images to Docker Hub

Each service has both `build:` and `image:`. `docker compose build` tags the
result with the `image:` name, `docker compose push` sends it to the registry
in that name, and `docker compose pull` downloads it on another machine.
The registry and account are the `IMAGE_NAMESPACE` variable, so the same
file publishes anywhere; the tags are the application versions
(`APP_VERSION`, `PROXY_VERSION`) and the H2 release (`H2_VERSION`):

```console
$ IMAGE_NAMESPACE=docker.io/rmotafreitas docker compose -f CA4/part2/compose.yaml config --images
docker.io/rmotafreitas/cogsi-ca4-h2:2.4.240
docker.io/rmotafreitas/cogsi-ca4-bookstore:1.0.0
docker.io/rmotafreitas/cogsi-ca4-proxy:1.0.0
```

As in Part 1 (section 4.8), the machine is not logged in to Docker Hub, so
the push was made to the local registry; the Docker Hub push is the same
two commands with the default namespace once `docker login` is done:

```bash
docker login -u rmotafreitas
docker compose -f CA4/part2/compose.yaml build && docker compose -f CA4/part2/compose.yaml push
```

With the local registry of section 4.8:

```bash
export IMAGE_NAMESPACE=localhost:5000/rmotafreitas
docker compose -f CA4/part2/compose.yaml build
docker compose -f CA4/part2/compose.yaml push
for r in cogsi-ca4-h2 cogsi-ca4-bookstore cogsi-ca4-proxy; do curl -s localhost:5000/v2/rmotafreitas/$r/tags/list; echo; done
```

```console
 localhost:5000/rmotafreitas/cogsi-ca4-h2:2.4.240 Pushed
 localhost:5000/rmotafreitas/cogsi-ca4-proxy:1.0.0 Pushed
 localhost:5000/rmotafreitas/cogsi-ca4-bookstore:1.0.0 Pushed
{"name":"rmotafreitas/cogsi-ca4-h2","tags":["2.4.240"]}
{"name":"rmotafreitas/cogsi-ca4-bookstore","tags":["1.0.0"]}
{"name":"rmotafreitas/cogsi-ca4-proxy","tags":["1.0.0"]}
```

To check that the published images are enough to run the environment, the
local copies were deleted and a second project (`-p cogsi-ca4-pulled`, its
own networks and volume, the proxy on port 8095) was started without
building:

```bash
export IMAGE_NAMESPACE=localhost:5000/rmotafreitas PROXY_PUBLISHED_PORT=8095
for r in cogsi-ca4-h2:2.4.240 cogsi-ca4-bookstore:1.0.0 cogsi-ca4-proxy:1.0.0; do docker rmi localhost:5000/rmotafreitas/$r; done
docker compose -f CA4/part2/compose.yaml -p cogsi-ca4-pulled up -d --pull always --no-build --wait
docker compose -f CA4/part2/compose.yaml -p cogsi-ca4-pulled ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
curl -s localhost:8095/books
docker compose -f CA4/part2/compose.yaml -p cogsi-ca4-pulled down -v
```

```console
 Image localhost:5000/rmotafreitas/cogsi-ca4-h2:2.4.240 Pulling
 Image localhost:5000/rmotafreitas/cogsi-ca4-bookstore:1.0.0 Pulling
 Image localhost:5000/rmotafreitas/cogsi-ca4-proxy:1.0.0 Pulling
 ...
SERVICE   IMAGE                                                   STATUS                    PORTS
db        localhost:5000/rmotafreitas/cogsi-ca4-h2:2.4.240        Up 11 seconds (healthy)   9092/tcp
proxy     localhost:5000/rmotafreitas/cogsi-ca4-proxy:1.0.0       Up 2 seconds (healthy)    0.0.0.0:8095->80/tcp, [::]:8095->80/tcp
web       localhost:5000/rmotafreitas/cogsi-ca4-bookstore:1.0.0   Up 9 seconds (healthy)    8080/tcp
[{"author":"Robert C. Martin","id":1,"price":30.0,"title":"Clean Code"},{"author":"Joshua Bloch","id":2,"price":40.0,"title":"Effective Java"}, ...]
```

`--pull always` forces the download even if an image with that name exists
locally, and `--no-build` makes Compose fail rather than build if an image is
missing, so the environment came only from the registry. The new project
started with an empty volume, so the database was created by the
entrypoint, and the API answered with the sample data. The three images are
also attached to the GitHub release of the tag `ca4-part2` (section 8).

---

## 6. Alternative solution - analysis and design

_Second week of the assignment._

---

## 7. Alternative solution - implementation

_Second week of the assignment._

---

## 8. Operative guidelines and team work

_Completed at the end of the assignment._

---

## 9. References

_Completed at the end of the assignment._
