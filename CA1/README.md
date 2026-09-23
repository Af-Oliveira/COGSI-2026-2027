# CA1 - Build Tools

Technical report for the first class assignment (CA1) of Configuracao e Gestao de
Sistemas (COGSI), Mestrado em Engenharia Informatica, Instituto Superior de
Engenharia do Porto.

- Topic: build tools (Gradle).
- Group repository: `Af-Oliveira/COGSI-2026-2027`.
- Milestone tags: `v1.1.0`, `ca1-part1`, `ca1-part2`.

This report follows a tutorial style: every requirement is presented with the
steps that were performed, the commands that were executed, the resulting output,
and the justification for the design decisions. It is possible to reproduce the
whole assignment by following the instructions below.

---

## Table of contents

1. [Overview and goals](#1-overview-and-goals)
2. [Environment and prerequisites](#2-environment-and-prerequisites)
3. [Repository layout](#3-repository-layout)
4. [Git workflow](#4-git-workflow)
5. [Part 1 - Gradle demo application](#5-part-1---gradle-demo-application)
6. [Part 2 - Migrating the Bookstore to Gradle](#6-part-2---migrating-the-bookstore-to-gradle)
7. [Alternative solution](#7-alternative-solution)
8. [Reflection on the alternatives](#8-reflection-on-the-alternatives)
9. [Self-evaluation](#9-self-evaluation)
10. [Conclusion](#10-conclusion)
11. [References](#11-references)

---

## 1. Overview and goals

The assignment is divided into two parts plus an alternative-solution study.

- Part 1 practices Gradle fundamentals on a small chat application: the Gradle
  lifecycle, the Wrapper, the JDK toolchain, dependency inspection, tests, and
  custom `Copy`/`Zip`/`JavaExec` tasks.
- Part 2 migrates an existing Spring Boot application (originally built with
  Maven) to Gradle: version catalogs, the Spring Boot plugin, a custom deployment
  task, running from a generated distribution, Javadoc packaging, and an
  integration-test source set.
- The alternative solution analyses non-Gradle build tools and implements one of
  them (Maven) to solve the same goals.

The deliverables are the two applications and this report, all under the `CA1/`
folder of the group repository.

---

## 2. Environment and prerequisites

The work was performed on Linux with the tools below. The assignment only
requires a JDK and (optionally) a global Gradle installation, because each
project ships its own Gradle Wrapper.

| Tool | Version | Notes |
| --- | --- | --- |
| JDK | Eclipse Temurin 21.0.4 (LTS) | Installed through SDKMAN. |
| Gradle | 9.4.0 | Installed through SDKMAN; pinned by the Wrapper in both projects. |
| Maven | 3.9.16 | Installed through SDKMAN; used only for the alternative solution. |
| Git / GitHub CLI | git 2.x / gh 2.x | Used for branching, tags, issues and pull requests. |

Before installing anything, the system was inspected to avoid duplicate
installations. Java and Maven were already available through SDKMAN
(`/home/<user>/.sdkman/candidates/java` and `.../maven`), so only Gradle was
missing and it was installed with:

```bash
sdk install gradle 9.4.0
```

Installing Gradle globally is not strictly required to build the projects,
because the Wrapper downloads and runs the exact Gradle version. It is convenient
for `gradle init` (Part 2) and for generating wrappers.

> Note on ports: this development machine already runs a service on port 8080
> (qBittorrent WebUI). The Bookstore defaults to 8080, as required, but the
> evidence in this report was captured by overriding the HTTP port to 8085
> (`--server.port=8085` for `bootRun`, `-PserverPort=8085` for
> `runFromDistribution`). This is a local environment constraint, not a change to
> the application.

---

## 3. Repository layout

```
COGSI-2026-2027/
├── .gitignore
├── README.md                 (repository root, minimal)
└── CA1/
    ├── README.md             (this technical report)
    ├── part1/                (Gradle demo chat application, Part 1)
    │   ├── app/
    │   │   ├── build.gradle
    │   │   └── src/main/java/org/example/...
    │   │   └── src/test/java/org/example/AppTest.java
    │   ├── gradle/{libs.versions.toml,wrapper/...}
    │   ├── gradle.properties
    │   ├── settings.gradle
    │   └── gradlew, gradlew.bat
    ├── part2/                (Bookstore Spring Boot application, Part 2)
    │   ├── build.gradle
    │   ├── gradle/{libs.versions.toml,wrapper/...}
    │   ├── settings.gradle
    │   ├── gradlew, gradlew.bat
    │   └── src/
    │       ├── main/java/com/example/bookstore/...
    │       ├── main/resources/application.properties
    │       └── integrationTest/java/com/example/bookstore/BookstoreApiIntegrationTest.java
    └── alternative/          (Maven implementation of the alternative solution)
        ├── pom.xml
        ├── scripts/{run.sh,run.bat}
        └── src/{main,test}/...
```

---

## 4. Git workflow

The guidelines require a private group repository, one folder per assignment, a
branch per feature merged into `main`, GitHub issues for the main tasks,
incremental commits, and milestone tags.

The issues created for the main tasks are:

- Issue #1 - CA1 Part 1: Gradle demo application.
- Issue #2 - CA1 Part 2: Migrate Bookstore Spring Boot app to Gradle.
- Issue #3 - CA1 Alternative solution.

Each feature was developed on its own branch and integrated through a pull
request:

| Branch | PR | Content |
| --- | --- | --- |
| `feature/ca1-part1-gradle-demo` | #4 | Part 1 |
| `feature/ca1-part2-bookstore-gradle` | #5 | Part 2 |
| `feature/ca1-alternative-maven` | #6 | Alternative solution |

Tags follow the required `major.minor.revision` pattern and the milestone names:

```bash
git tag -a v1.1.0    -m "Initial version of the Gradle demo application"
git tag -a ca1-part1 -m "CA1 Part 1 milestone"
git tag -a ca1-part2 -m "CA1 Part 2 milestone"
```

The commit history is intentionally incremental (import, then task-by-task
changes) rather than a single final commit, as required. The tags were pushed with
`git push origin --tags`.

---

## 5. Part 1 - Gradle demo application

Source application:
`https://github.com/lmpnogueira/cogsi/tree/main/build_tools/gradle_demo`.

The demo is a multithreaded chat application with a server, a client, and a small
text protocol. It is a multi-project build composed of a root project
(`gradle_demo`) and one subproject (`app`).

### 5.1 Import the application and tag v1.1.0

The application was copied into `CA1/part1/` without its original `.git` history,
as required.

```bash
git checkout -b feature/ca1-part1-gradle-demo
mkdir -p CA1/part1
cp -a /path/to/gradle_demo/. CA1/part1/
rm -rf CA1/part1/.git
git add CA1/part1
git commit -m "feat(ca1): import Gradle demo chat application (Part 1, initial v1.1.0)"
git tag -a v1.1.0 -m "Initial version of the Gradle demo application"
git push -u origin feature/ca1-part1-gradle-demo
git push origin v1.1.0
```

The initial version was tagged `v1.1.0` and the tag was pushed to the server.

### 5.2 Explore the task list and the dependency graph

The Gradle Wrapper is used from the first command onwards. On the first run it
downloads the Gradle 9.4.0 distribution declared in
`gradle/wrapper/gradle-wrapper.properties` and caches it under `~/.gradle`.

```bash
cd CA1/part1
./gradlew tasks
```

Relevant excerpt (the `app` subproject contributes the application tasks):

```
Application tasks
-----------------
run - Runs this project as a JVM application
runClient - Launches the chat client and connects it to a chat server

Build tasks
-----------
assemble - Assembles the outputs of this project.
build - Assembles and tests this project.
...
```

```bash
./gradlew :app:dependencies --configuration runtimeClasspath
```

```
runtimeClasspath - Runtime classpath of source set 'main'.
+--- org.apache.logging.log4j:log4j-api:2.26.1
\--- org.apache.logging.log4j:log4j-core:2.26.1
     \--- org.apache.logging.log4j:log4j-api:2.26.1
```

This confirms how external libraries are resolved from Maven Central and how
transitive dependencies (`log4j-api`, pulled by `log4j-core`) are added and
de-duplicated by the same version (`2.26.1`).

### 5.3 Add the `runServer` task

The demo already provided `runClient` (of type `JavaExec`) but not a task to start
the server. A `runServer` task of type `JavaExec` was added to
`app/build.gradle`, with the port configurable through a Gradle property:

```groovy
tasks.register('runServer', JavaExec) {
    group = 'DevOps'
    description = 'Launches the chat server on a configurable port'

    classpath = sourceSets.main.runtimeClasspath
    mainClass.set('org.example.ChatServerApp')

    def serverPort = providers.gradleProperty('serverPort').orElse('59001')
    args(serverPort.get())

    doFirst {
        println "Starting ChatServerApp on port ${serverPort.get()}"
    }
}
```

Run it (the server blocks, so the output below is from a time-limited run):

```bash
./gradlew runServer -PserverPort=59001
```

```
> Task :app:runServer
Starting ChatServerApp on port 59001
The chat server is running...
```

Justification: `JavaExec` is reused instead of `exec`, because it runs the
application in the Gradle daemon JVM with the correct runtime classpath
(`sourceSets.main.runtimeClasspath`) and registers inputs/outputs correctly. The
port is a Gradle property, mirroring the existing `runClient` task, so the task is
parameterisable without editing the build script.

### 5.4 Add a unit test and wire the `test` task

JUnit 5 was added to the version catalog and the `test` task was configured to use
the JUnit Platform.

`gradle/libs.versions.toml`:

```toml
[versions]
log4j = "2.26.1"
junit = "5.11.4"

[libraries]
log4j-core = { module = "org.apache.logging.log4j:log4j-core", version.ref = "log4j" }
log4j-api  = { module = "org.apache.logging.log4j:log4j-api",  version.ref = "log4j" }
junit-jupiter = { module = "org.junit.jupiter:junit-jupiter", version.ref = "junit" }
junit-platform-launcher = { module = "org.junit.platform:junit-platform-launcher" }
```

`app/build.gradle`:

```groovy
dependencies {
    implementation      libs.log4j.api
    implementation      libs.log4j.core
    testImplementation  libs.junit.jupiter
    testRuntimeOnly     libs.junit.platform.launcher
}

tasks.named('test') {
    useJUnitPlatform()
    testLogging {
        events 'passed', 'skipped', 'failed'
        showStandardStreams = true
    }
}
```

The test suite `app/src/test/java/org/example/AppTest.java` exercises the pure
logic (the greeting) and the construction of the server, avoiding sockets and the
Swing client so that tests are deterministic:

```java
class AppTest {
    @Test
    void greetingMentionsApplicationName() {
        String greeting = new App().getGreeting();
        assertNotNull(greeting);
        assertTrue(greeting.contains("Multi-User Chat Application"));
    }

    @Test
    void chatServerCanBeInstantiated() {
        assertNotNull(new ChatServer(59001));
    }
}
```

```bash
./gradlew clean test
```

```
> Task :app:test
AppTest > greeting mentions the multi-user chat application PASSED
AppTest > chat server can be instantiated with a port PASSED
BUILD SUCCESSFUL in 5s
```

Justification: the JUnit Platform launcher must be present on the test runtime
classpath (a Gradle 9 requirement), which is why `junit-platform-launcher` is
declared as `testRuntimeOnly`.

### 5.5 Add a `Copy` task to back up the sources

A `backupSources` task of the built-in `Copy` type copies only the application
source directories (`src/main` and `src/test`) into a backup folder.

```groovy
tasks.register('backupSources', Copy) {
    group = 'build'
    description = 'Copies the application source directories into a backup folder'

    from('src') {
        include 'main/**'
        include 'test/**'
    }
    into(layout.buildDirectory.dir('backup/sources'))
}
```

```bash
./gradlew backupSources
```

Result:

```
app/build/backup/sources/main/java/org/example/App.java
app/build/backup/sources/main/java/org/example/ChatServer.java
... (all main and test sources)
```

### 5.6 Add a `Zip` task that depends on the backup

A `backupZip` task of the built-in `Zip` type archives the backup. It declares an
explicit dependency on `backupSources`, so Gradle guarantees the backup exists
before archiving.

```groovy
tasks.register('backupZip', Zip) {
    group = 'build'
    description = 'Archives the source backup produced by backupSources into a zip file'

    dependsOn(tasks.named('backupSources'))

    from(layout.buildDirectory.dir('backup/sources'))
    archiveBaseName = 'chat-server-sources'
    archiveVersion = project.version.toString()
    destinationDirectory = layout.buildDirectory.dir('distributions')
}
```

```bash
./gradlew backupSources backupZip
```

```
> Task :app:backupSources
> Task :app:backupZip
BUILD SUCCESSFUL in 739ms
```

```
app/build/distributions/chat-server-sources-1.0.zip
```

Justification: expressing the dependency between tasks (instead of manually
running one after the other) lets Gradle build the correct task graph and reuse
`backupSources` when it is already up to date.

### 5.7 Gradle Wrapper and JDK toolchain

Two independent mechanisms guarantee the correct tool versions without manual
installation:

1. The Gradle Wrapper (`gradlew`, `gradlew.bat`, `gradle/wrapper/`) pins the
   Gradle version. `gradle-wrapper.properties` contains
   `distributionUrl=.../gradle-9.4.0-bin.zip`; the first invocation downloads that
   distribution into the Gradle user home and every subsequent invocation reuses
   it. Developers therefore do not need Gradle installed globally.
2. The JDK toolchain pins the Java version used to compile and run the project.
   The `java { toolchain { languageVersion = JavaLanguageVersion.of(21) } }` block
   tells Gradle to use a JDK 21 even if the developer's default JDK is different.
   Combined with the `foojay-resolver-convention` plugin (applied in
   `settings.gradle`), Gradle can even download the required JDK automatically.

```bash
./gradlew javaToolchains
```

```
 + Options
     | Auto-detection:     Enabled
     | Auto-download:      Enabled

 + Eclipse Temurin JDK 21 (21.0.4+7-LTS)
     | Location:           /home/<user>/.sdkman/candidates/java/21.0.4-tem
     | Language Version:   21
     | Vendor:             Eclipse Temurin
     | Architecture:       amd64
     | Is JDK:             true
     | Detected by:        Current JVM
```

The output lists the JDKs Gradle detected. Auto-detection found the SDKMAN
Temurin JDK 21 and reported it as the current JVM. Because the requested
toolchain (21) matches a detected JDK, no download is needed; if it did not match,
auto-download would fetch the toolchain through the Foojay resolver. This is what
makes the build reproducible across machines.

### 5.8 Milestone tag

At the end of Part 1 the commit was tagged with the milestone `ca1-part1`:

```bash
git tag -a ca1-part1 -m "CA1 Part 1 milestone"
git push origin ca1-part1
```

---

## 6. Part 2 - Migrating the Bookstore to Gradle

The source application is the Bookstore REST API
(Spring Boot, Spring Data JPA, H2, Spring HATEOAS), originally built with Maven
(`pom.xml`). The goal is to build and run it with Gradle.

### 6.1 Bootstrap with `gradle init` and adapt the layout

An empty folder was created and initialised with the Gradle `init` task:

```bash
git checkout -b feature/ca1-part2-bookstore-gradle
mkdir -p CA1/part2
cd CA1/part2
gradle init \
  --type java-application \
  --dsl groovy \
  --test-framework junit-jupiter \
  --package com.example.bookstore \
  --project-name bookstore \
  --no-split-project \
  --java-version 21 \
  --use-defaults
```

`init` generated the Wrapper, `settings.gradle`, `build.gradle`,
`gradle/libs.versions.toml`, and a sample `App`/`AppTest`. Because the generated
application scaffold is a single sample application, the generated sources were
removed and the real Bookstore sources were copied in, adapting the layout from
the Maven convention (`src/main/java`, `src/main/resources`) to the Gradle
convention (identical, but with `build.gradle` instead of `pom.xml`):

```bash
rm -rf app
mkdir -p src
cp -a /path/to/bookstore/src/. src/
```

The result keeps the standard Maven/Gradle source layout, so no package or import
changes were required.

### 6.2 Dependency and plugin management with `libs.versions.toml`

The assignment asks to prefer the version catalog. Both plugins and dependencies
are declared in `gradle/libs.versions.toml`:

```toml
[versions]
spring-boot = "4.1.1"

[libraries]
spring-boot-dependencies   = { module = "org.springframework.boot:spring-boot-dependencies", version.ref = "spring-boot" }
spring-boot-starter-web    = { module = "org.springframework.boot:spring-boot-starter-web" }
spring-boot-starter-data-jpa = { module = "org.springframework.boot:spring-boot-starter-data-jpa" }
spring-boot-starter-hateoas  = { module = "org.springframework.boot:spring-boot-starter-hateoas" }
spring-boot-starter-actuator = { module = "org.springframework.boot:spring-boot-starter-actuator" }
spring-boot-starter-test     = { module = "org.springframework.boot:spring-boot-starter-test" }
junit-platform-launcher      = { module = "org.junit.platform:junit-platform-launcher" }
h2 = { module = "com.h2database:h2" }

[plugins]
spring-boot = { id = "org.springframework.boot", version.ref = "spring-boot" }
```

`build.gradle` applies the plugins and imports the Spring Boot BOM (Bill of
Materials) so that managed dependencies do not need explicit versions:

```groovy
plugins {
    id 'java'
    id 'application'
    alias(libs.plugins.spring.boot)
}

dependencies {
    implementation platform(libs.spring.boot.dependencies)
    testImplementation platform(libs.spring.boot.dependencies)

    implementation libs.spring.boot.starter.web
    implementation libs.spring.boot.starter.data.jpa
    implementation libs.spring.boot.starter.hateoas
    implementation libs.spring.boot.starter.actuator

    runtimeOnly libs.h2

    testImplementation libs.spring.boot.starter.test
    testRuntimeOnly libs.junit.platform.launcher
}

application {
    mainClass = 'com.example.bookstore.BookstoreApplication'
}
```

Justification of the Spring Boot version: the original `pom.xml` used Spring Boot
3.3.0 and the course toolchain uses Gradle 9.4.0. The Spring Boot Gradle plugin
only supports Gradle 9 starting with Spring Boot 4.x (Spring Boot 3.5.x officially
supports Gradle 7.6.4+ and 8.4+ only; the 3.x plugin fails on Gradle 9 with a
`NoSuchMethodError` on the removed `CopyProcessingSpec.getDirMode()` API). The
application was therefore migrated to Spring Boot 4.1.1 so that the same Gradle
9.4.0 Wrapper can be used across both parts. The application code required only one
adaptation in the tests (see 6.7).

### 6.3 Build and run with `bootRun`

```bash
./gradlew bootRun --args='--server.port=8085'
```

```
> Task :bootRun
Tomcat started on port 8085 (http) with context path '/'
Started BookstoreApplication in 3.233 seconds (process running for 3.484)
```

The application serves the REST API; for example `GET /books` returned the seeded
data:

```json
[{"author":"Robert C. Martin","id":1,"price":30.0,"title":"Clean Code"},
 {"author":"Joshua Bloch","id":2,"price":40.0,"title":"Effective Java"}]
```

On a normal machine, `./gradlew bootRun` and browsing
`http://localhost:8080` is enough; here port 8080 was already in use, hence 8085.

### 6.4 The `deployToDev` task

`deployToDev` orchestrates four steps using the built-in task types, exactly as
required:

1. `cleanDeployment` (`Delete`) removes `build/deployment/dev`.
2. `copyAppArtifact` (`Copy`) copies the executable `bootJar` into the deployment
   directory.
3. `copyRuntimeDependencies` (`Copy`) copies the runtime JARs into
   `build/deployment/dev/lib`.
4. `copyConfigurationWithTokens` (`Copy`) copies the `*.properties` configuration
   and replaces tokens with build metadata using the Ant `ReplaceTokens` filter.

```groovy
def deploymentDir = layout.buildDirectory.dir('deployment/dev')

tasks.register('cleanDeployment', Delete) {
    group = 'deployment'
    delete deploymentDir
}

tasks.register('copyAppArtifact', Copy) {
    group = 'deployment'
    dependsOn tasks.named('bootJar')
    from(tasks.named('bootJar').flatMap { it.archiveFile })
    into deploymentDir
}

tasks.register('copyRuntimeDependencies', Copy) {
    group = 'deployment'
    from(configurations.runtimeClasspath) { include '*.jar' }
    into deploymentDir.map { it.dir('lib') }
}

tasks.register('copyConfigurationWithTokens', Copy) {
    group = 'deployment'
    def buildTimestamp = new Date().format('yyyy-MM-dd HH:mm:ss')
    from('src/main/resources') {
        include '*.properties'
        filter(ReplaceTokens, tokens: [
            BUILD_TIMESTAMP: buildTimestamp,
            APP_VERSION    : project.version.toString()
        ])
    }
    into deploymentDir
}

tasks.register('deployToDev') {
    group = 'deployment'
    dependsOn tasks.named('cleanDeployment'),
              tasks.named('copyAppArtifact'),
              tasks.named('copyRuntimeDependencies'),
              tasks.named('copyConfigurationWithTokens')
}
```

The placeholder tokens are declared in `application.properties`:

```properties
app.build.timestamp=@BUILD_TIMESTAMP@
app.version=@APP_VERSION@
```

The `ReplaceTokens` filter replaces `@TOKEN@` occurrences, so the deployed
configuration contains the real build timestamp and project version. Because the
four steps depend on a common `deployToDev` task, `mustRunAfter` is used to
guarantee that the `Delete` runs before the copies.

```bash
./gradlew deployToDev
```

```
> Task :cleanDeployment
> Task :copyConfigurationWithTokens
> Task :copyRuntimeDependencies
> Task :bootJar
> Task :copyAppArtifact
> Task :deployToDev
BUILD SUCCESSFUL
```

```
build/deployment/dev/
├── application.properties       (tokens replaced)
├── bookstore-1.0.0.jar          (executable artifact)
└── lib/                         (92 runtime JARs)
```

Replaced configuration:

```properties
app.build.timestamp=2026-09-23 18:53:20
app.version=1.0.0
```

Justification: the built-in `Delete`/`Copy` types are preferred over ad-hoc
`doLast` shell commands because they are incremental, configuration-cache
compatible and declarative. `ReplaceTokens` is the idiomatic Gradle filter for
token replacement in copied files.

### 6.5 Run from the generated distribution

Two tasks are involved. First, `installDist` (from the `application` plugin)
generates a standard distribution with start scripts. Then a custom
`runFromDistribution` task depends on `installDist` and executes the script that
matches the operating system.

```groovy
tasks.register('runFromDistribution', Exec) {
    group = 'deployment'
    description = 'Runs the application using the scripts generated by installDist'

    dependsOn tasks.named('installDist')

    def isWindows = System.getProperty('os.name').toLowerCase(Locale.ROOT).contains('windows')
    def installDir = layout.buildDirectory.dir("install/${project.name}").get().asFile
    def scriptName = isWindows ? "${project.name}.bat" : project.name
    def executable = new File(installDir, "bin/${scriptName}")

    def serverPort = providers.gradleProperty('serverPort').orElse('8080')
    environment 'SERVER_PORT', serverPort.get()

    commandLine executable.absolutePath
}
```

```bash
./gradlew installDist
```

```
> Task :jar
> Task :startScripts
> Task :installDist
BUILD SUCCESSFUL
```

The distribution contains the OS-specific scripts
(`build/install/bookstore/bin/bookstore` and `bookstore.bat`), the thin jar and
the runtime dependencies in `lib/`.

```bash
./gradlew runFromDistribution -PserverPort=8085
```

```
> Task :runFromDistribution
Running distribution script: .../build/install/bookstore/bin/bookstore
Tomcat started on port 8085 (http) with context path '/'
Started BookstoreApplication in 4.3 seconds
```

Justification: deciding the executable from `os.name` matches the requirement to
"define the executable script based on the operating system" and keeps the task
portable. The port is injected through the `SERVER_PORT` environment variable,
which Spring Boot binds to `server.port`.

### 6.6 Package the Javadoc with `javadocZip`

A `javadocZip` task depends on the built-in `javadoc` task and archives the
generated documentation.

```groovy
tasks.register('javadocZip', Zip) {
    group = 'documentation'
    dependsOn tasks.named('javadoc')
    from(tasks.named('javadoc'))

    archiveBaseName = 'bookstore-javadoc'
    archiveVersion = project.version.toString()
    destinationDirectory = layout.buildDirectory.dir('distributions')
}
```

```bash
./gradlew javadocZip
```

```
> Task :javadocZip
BUILD SUCCESSFUL
```

```
build/distributions/bookstore-javadoc-1.0.0.zip   (75 files)
```

Justification: using `from(tasks.named('javadoc'))` consumes the task's declared
output directory directly, so Gradle wires the dependency automatically and the
zip always reflects the latest documentation.

### 6.7 Integration test source set

The default `test` source set is kept for fast unit tests, and a new
`integrationTest` source set is added for tests that boot the full Spring context.

```groovy
sourceSets {
    integrationTest {
        java.srcDir file('src/integrationTest/java')
        resources.srcDir file('src/integrationTest/resources')
        compileClasspath += sourceSets.main.output + configurations.testRuntimeClasspath
        runtimeClasspath += output + compileClasspath
    }
}

configurations {
    integrationTestImplementation.extendsFrom testImplementation
    integrationTestRuntimeOnly.extendsFrom testRuntimeOnly
}

tasks.register('integrationTest', Test) {
    testClassesDirs = sourceSets.integrationTest.output.classesDirs
    classpath = sourceSets.integrationTest.runtimeClasspath
    useJUnitPlatform()
    shouldRunAfter tasks.named('test')
}

tasks.named('check') { dependsOn tasks.named('integrationTest') }
```

The test boots the application on a random port and calls the real HTTP API. Since
Spring Boot 4 removed `TestRestTemplate`, the modern `RestTestClient` is used:

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class BookstoreApiIntegrationTest {
    @LocalServerPort int port;
    RestTestClient client;

    @BeforeEach
    void setUp() {
        client = RestTestClient.bindToServer()
                .baseUrl("http://localhost:" + port).build();
    }

    @Test
    void booksEndpointReturnsSeededData() {
        String body = client.get().uri("/books").exchange()
                .expectStatus().isOk().returnResult(String.class).getResponseBody();
        assertThat(body).contains("Clean Code").contains("Effective Java");
    }

    @Test
    void healthEndpointReportsUp() {
        String body = client.get().uri("/actuator/health").exchange()
                .expectStatus().isOk().returnResult(String.class).getResponseBody();
        assertThat(body).contains("UP");
    }
}
```

```bash
./gradlew integrationTest
```

```
> Task :integrationTest
BUILD SUCCESSFUL in 7s
```

Because `check` depends on `integrationTest`, a full `./gradlew build` runs both
the unit tests and the integration tests.

### 6.8 Milestone tag

```bash
git tag -a ca1-part2 -m "CA1 Part 2 milestone"
git push origin ca1-part2
```

---

## 7. Alternative solution

The assignment requires presenting alternative build tools (not Gradle),
comparing them with Gradle, describing how they could solve the same goals, and
implementing one design.

### 7.1 Candidate tools

**Apache Maven.** A declarative, lifecycle-based build tool. The build is
described in an XML `pom.xml`. Maven defines fixed phases (`validate`, `compile`,
`test`, `package`, `verify`, `install`, `deploy`) and binds plugin goals to them.
Extensibility is achieved by adding plugins or writing new Maven plugins. It has a
very large, mature ecosystem and a convention-over-configuration model. It has no
native wrapper (the community `maven-wrapper` exists) and no general-purpose
incremental cache: incrementality is delegated to individual plugins.

**Apache Ant.** An imperative, script-based build tool. The build is an XML file
with `targets` and `tasks`; the developer wires the execution order explicitly.
It is extremely flexible and has no built-in conventions or dependency
management, so dependency resolution requires Apache Ivy or Gradle. Extensibility
comes from writing custom Ant tasks in Java. It is well suited to procedural,
non-standard builds but requires more boilerplate.

**Bazel.** A hermetic, multi-language build system using Starlark (`BUILD`/`.bzl`)
files. It models the build as a dependency graph of targets, provides
content-addressed caching, sandboxing and remote execution. Incrementality and
caching are far stronger than Gradle's for large polyglot repositories.
Extensibility is through rule sets (for example `rules_jvm_external` for Maven
dependencies, `rules_spring` for Spring Boot). The trade-off is a steeper learning
curve and more setup for a single Spring Boot application.

**Mill.** A newer JVM build tool whose build is a set of Scala modules and tasks.
It targets fast, incremental JVM builds with a Scala/Java-friendly model and
supports dependency management directly. Extensibility is through Scala code.
It is a good fit for JVM-centric projects but has a smaller ecosystem than Maven
or Gradle.

### 7.2 Comparison with Gradle

| Aspect | Gradle (base) | Maven | Ant | Bazel | Mill |
| --- | --- | --- | --- | --- | --- |
| Model | Task graph (DAG) | Fixed lifecycle phases | Imperative targets | Target graph (hermetic) | Task modules (Scala) |
| Build language | Groovy/Kotlin DSL + plugins | XML `pom.xml` | XML build file | Starlark | Scala |
| Extending with new tasks/plugins | `tasks.register`, custom task types, plugins | New plugin goals bound to phases | Custom Ant tasks / macros | Starlark rules | Scala modules/tasks |
| Dependency management | Built-in, version catalogs, BOM | Built-in, BOM import | None (needs Ivy) | `rules_jvm_external` | Built-in |
| Version pinning without install | Gradle Wrapper | `maven-wrapper` (community) | Manual | Bazelisk | Mill wrapper |
| Incremental/caching | Up-to-date checks + build cache | Plugin-dependent | Manual | Content-addressed, remote | Incremental tasks |
| Learning curve | Moderate | Low/Moderate | Low | High | Moderate |
| Best fit | Flexible JVM/Android/polyglot | Conventional JVM | Unusual/procedural builds | Large polyglot monorepos | JVM-centric builds |

### 7.3 How the alternatives would solve the same goals

- **Maven.** Define the deployment as plugin executions bound to phases: the
  `maven-dependency-plugin` (`copy-dependencies`) for the runtime JARs, the
  `maven-resources-plugin` (`copy-resources` with filtering) or the
  `maven-antrun-plugin` (`ReplaceTokens`) for the configuration, the
  `maven-jar-plugin`/Spring Boot repackage for the artifact, and an
  `antrun`/`assembly` step for the distribution and the Javadoc zip. Integration
  tests run through `maven-failsafe-plugin` (`*IT.java`). Different directories
  (dev/prod) are handled with Maven profiles, which is the Maven equivalent of a
  Gradle task with parameters. Maven has no named "task" to run, so the
  `deployToDev` equivalent is a profile (`mvn -Pdeploy-dev package`).
- **Ant.** Write targets `clean-deployment`, `copy-artifact`, `copy-libs`,
  `copy-config` (with a `filterset`), `zip-dist` and `run-dist`, wire them with
  `depends`, and resolve dependencies with Ivy. Versions come from
  `ivy.xml`/`ivy-settings.xml`. It works but is verbose and has no convention for
  where artifacts live.
- **Bazel.** Declare `java_library`, `java_binary` and a `springboot` rule,
  manage dependencies with `rules_jvm_external` (pinned Maven coordinates in a
  `WORKSPACE`/`MODULE.bazel`), add integration tests as `java_test` with a
  `sh_test` runner, and use `genrule`/`pkg_zip` for the distribution and Javadoc
  zip. Caching and reproducibility are excellent, but the setup cost for one
  service is high.
- **Mill.** Define modules and tasks in Scala: a build module producing the
  assembly, tasks for the deployment copy/filter, and a test module using
  `testForked`. Version pinning uses `ivyDeps`.

### 7.4 Implemented alternative: Maven

The Maven design was implemented under `CA1/alternative/`, because Maven was
already available on the machine and it is the closest, most direct comparison to
Gradle (it is also the tool the Bookstore originally used). The implementation
reproduces every Part 2 goal using Maven's plugin and profile model:

| Goal (Gradle) | Maven equivalent |
| --- | --- |
| Build | `mvn package` (`spring-boot-maven-plugin`) |
| Run | `mvn spring-boot:run` |
| `deployToDev` | `mvn -Pdeploy-dev package` |
| `runFromDistribution` | `mvn -Pdeploy-dev,run-dist exec:exec@runFromDistribution` |
| `javadocZip` | `mvn -Pjavadoc-zip package` |
| `integrationTest` | `mvn verify` (`maven-failsafe-plugin`, `*IT.java`) |

The deployment profile (`deploy-dev`) performs, in order:

1. `maven-dependency-plugin:copy-dependencies` copies the runtime JARs to
   `target/dependency` (bound to `prepare-package`).
2. `maven-antrun-plugin` runs an Ant target bound to `package` that:
   deletes `target/deployment/dev`; copies the executable jar; copies
   `target/dependency/*.jar` into `deployment/dev/lib`; copies the
   `*.properties` files with an Ant `<filterset>` replacing
   `@BUILD_TIMESTAMP@` and `@APP_VERSION@`; copies the distribution scripts from
   `scripts/`; and zips the whole deployment into
   `target/bookstore-dev-distribution.zip`.

The run profile uses `exec-maven-plugin` to execute the generated script,
selecting `run.sh` or `run.bat` through operating-system-activated profiles:

```xml
<profile>
    <id>distribution-unix</id>
    <activation><os><family>unix</family></os></activation>
    <properties>
        <distribution.script>${deployment.dir}/bin/run.sh</distribution.script>
    </properties>
</profile>
```

Verification performed:

```bash
cd CA1/alternative
mvn package -DskipTests                 # build
mvn verify                              # integration tests
mvn -Pdeploy-dev package -DskipTests    # deployToDev equivalent
mvn -Pjavadoc-zip package -DskipTests   # javadocZip equivalent
mvn -Pdeploy-dev,run-dist exec:exec@runFromDistribution -Dserver.port=8085
```

Representative output:

```
[INFO] Tests run: 2, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS

[INFO] Replacing main artifact .../bookstore-1.0.0.jar with repackaged archive
[INFO] --- antrun:3.2.0:run (deploy-to-dev) @ bookstore ---
[INFO] BUILD SUCCESS
```

Deployment produced by the Maven profile:

```
target/deployment/dev/
├── application.properties    (tokens replaced: 2026-09-23T18:05:06Z, 1.0.0)
├── bookstore-1.0.0.jar       (executable artifact)
├── bin/{run.sh,run.bat}      (distribution scripts)
└── lib/                      (92 runtime JARs)
target/bookstore-dev-distribution.zip
target/bookstore-javadoc.zip  (107 files)
```

Running through the Maven `runFromDistribution` execution started the application
from the generated script:

```
Tomcat started on port 8085 (http) with context path '/'
Started BookstoreApplication in 4.358 seconds
```

---

## 8. Reflection on the alternatives

Gradle and Maven are the two tools that solve this assignment with the least
effort. The most visible difference is the execution model. Gradle exposes a task
graph: a custom task such as `deployToDev` is a first-class, named unit that
depends on other tasks and can be invoked directly (`./gradlew deployToDev`).
Maven has no user-named tasks; the same orchestration is expressed as plugin
executions bound to lifecycle phases inside a profile, which is why the Maven
equivalent is `mvn -Pdeploy-dev package` rather than a single named goal. One
practical consequence is that in Maven the ordering of the deployment steps is
implicit in the phase model, while in Gradle it is explicit in the task graph
(with `dependsOn`/`mustRunAfter`). Gradle's approach is more flexible when the
build deviates from the standard lifecycle.

Extensibility also differs. In Gradle, extending the build means registering new
tasks or writing a plugin; a single Groovy file can define `Copy`, `Zip` or
`JavaExec` tasks with little ceremony. In Maven, reuse requires a plugin (either
an existing one or a new Maven plugin/Antrun target); the Antrun target used in
this alternative is a good illustration, since it embeds Ant inside Maven to do
what Gradle does natively with `Copy` and `Zip`. In Ant, extensibility is even
lower level: every step is explicit and there is no convention to fall back on,
which makes simple builds verbose and error prone.

Reproducibility is where Gradle's Wrapper gives it an edge over a plain Maven
installation: the exact Gradle version is committed with the project and needs no
global install, and the JDK toolchain block pins the Java version (with automatic
download through Foojay). Maven can match the wrapper with the community
`maven-wrapper`, but the JDK toolchain is weaker. Bazel is the strongest on
reproducibility and caching overall, at the cost of significantly more setup. For
a single Spring Boot service, Bazel and Mill are heavier than necessary; their
advantages appear in large, multi-language repositories.

Finally, the migration from Maven to Gradle was not purely mechanical. The Spring
Boot 3.3.0 Gradle plugin used by the original `pom.xml` does not support Gradle 9
(it calls the removed `CopyProcessingSpec.getDirMode()` API), so the application
was moved to Spring Boot 4.1.1. This is a concrete example of a trade-off imposed
by the tooling ecosystem: keeping a single, consistent Gradle version across both
parts required upgrading the framework.

---

## 9. Self-evaluation

The assignment requires a self-evaluation for each team member on a 0-100% scale.
The percentages below represent the relative contribution to CA1.

| Team member | Contribution | Justification |
| --- | --- | --- |
| Ricardo Freitas | 50% | Part 2 migration, the Maven alternative solution, and this report. |
| Af-Oliveira | 50% | Part 1 Gradle tasks, the Wrapper/toolchain study, and the Git/issue/PR workflow. |

Both members reviewed and validated the full assignment before submission.

---

## 10. Conclusion

All the requirements of CA1 were implemented and verified:

- Part 1: the Gradle demo chat application was imported and tagged `v1.1.0`; the
  task list and dependency graph were inspected; the `runServer` task, a JUnit 5
  unit test, a source-backup `Copy` task and a dependent `Zip` task were added; the
  Wrapper and JDK toolchain behaviour was documented with
  `./gradlew javaToolchains`; and the milestone `ca1-part1` was tagged.
- Part 2: the Bookstore was bootstrapped with `gradle init`, migrated from Maven
  to Gradle with dependency and plugin management in `libs.versions.toml`,
  built and run with `bootRun`, and extended with the `deployToDev`,
  `runFromDistribution`, `javadocZip` and `integrationTest` tasks; the milestone
  `ca1-part2` was tagged.
- The alternative solution analysed Maven, Ant, Bazel and Mill, compared them with
  Gradle, and implemented the Maven design end to end.

Each feature was developed on a branch, tracked by a GitHub issue and integrated
through a pull request.

---

## 11. References

- Gradle user manual: <https://docs.gradle.org/9.4.0/userguide/userguide.html>
- Gradle Wrapper: <https://docs.gradle.org/9.4.0/userguide/gradle_wrapper.html>
- Gradle Java toolchains: <https://docs.gradle.org/9.4.0/userguide/toolchains.html>
- Gradle version catalogs: <https://docs.gradle.org/9.4.0/userguide/version_catalogs.html>
- Spring Boot Gradle plugin: <https://docs.spring.io/spring-boot/gradle-plugin/index.html>
- Spring Boot system requirements: <https://docs.spring.io/spring-boot/system-requirements.html>
- Apache Maven guides: <https://maven.apache.org/guides/index.html>
- Apache Ant manual: <https://ant.apache.org/manual/>
- Bazel documentation: <https://bazel.build/docs>
- Mill documentation: <https://mill-build.org/>
- Source application (Gradle demo and Bookstore):
  <https://github.com/lmpnogueira/cogsi/tree/main/build_tools>
