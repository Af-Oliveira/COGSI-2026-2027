# CA1 - Build Tools

Technical report for the first class assignment (CA1) of Configuracao e Gestao de
Sistemas (COGSI), Mestrado em Engenharia Informatica, Instituto Superior de
Engenharia do Porto.

- Topic: build tools.
- Group repository: `Af-Oliveira/COGSI-2026-2027`.
- Milestone tags: `v1.1.0`, `ca1-part1`, `ca1-part2`.
- Applications: Gradle demo chat application (Part 1), Bookstore Spring Boot
  application converted from Maven to Gradle (Part 2), Bookstore Spring Boot
  application automated with Apache Ant and Apache Ivy (alternative solution).

This report follows a tutorial style and is organised exercise by exercise:
each requirement of the assignment is quoted before the sequence of commands
that implements it, the output produced by those commands, and the explanation
of each command. Executing the instructions in order reproduces the whole
assignment.

---

## Table of contents

1. [Overview](#1-overview)
2. [Environment and prerequisites](#2-environment-and-prerequisites)
3. [Repository layout](#3-repository-layout)
4. [Operative guidelines](#4-operative-guidelines)
5. [Technical report](#5-technical-report)
6. [Part 1 - First week](#6-part-1---first-week)
7. [Part 2 - Second week](#7-part-2---second-week)
8. [Analysis of alternative solutions](#8-analysis-of-alternative-solutions)
9. [Implementation of the alternative solution](#9-implementation-of-the-alternative-solution)
10. [Reflection](#10-reflection)
11. [Conclusion](#11-conclusion)
12. [References](#12-references)

---

## 1. Overview

CA1 is divided into two parts plus an alternative-solution study.

- Part 1 practices Gradle fundamentals on a small chat application: the Gradle
  lifecycle, the Wrapper, the JDK toolchain, dependency inspection, unit tests,
  and custom `Copy`/`Zip`/`JavaExec` tasks.
- Part 2 converts an existing Spring Boot application (the Bookstore, originally
  built with Maven) to Gradle: version catalogs, the Spring Boot plugin, a
  deployment task, running from a generated distribution, Javadoc packaging, and
  an integration-test source set.
- The alternative solution presents non-Gradle build tools, compares them with
  Gradle, describes how each would solve the same goals, and implements one of
  the designs (Apache Ant with Apache Ivy).

The deliverables are the two applications, the Ant implementation and this
report, all under the `CA1/` folder of the group repository.

---

## 2. Environment and prerequisites

The work was performed on Linux with the tools in the table below.

| Tool | Version | Purpose |
| --- | --- | --- |
| JDK | Eclipse Temurin 21.0.4 (LTS) | Compiles and runs both applications. |
| Gradle | 9.4.0 | Build tool for Parts 1 and 2; pinned by the Wrapper. |
| Apache Ant | 1.10.17 | Build tool for the alternative solution. |
| Apache Ivy | 2.6.0 | Dependency management for the Ant build. |
| Git / GitHub CLI | git 2.x / gh 2.x | Branching, tags, issues and pull requests. |

The JDK, Gradle and Ant are installed with SDKMAN. Ant does not include
dependency management, so Apache Ivy is downloaded into the Ant user library
directory (`~/.ant/lib`), which Ant adds to its own classpath at startup.

```bash
# install the JDK, Gradle and Ant through SDKMAN
sdk install java 21.0.4-tem
sdk install gradle 9.4.0
sdk install ant 1.10.17

# install Apache Ivy into the Ant user library directory
mkdir -p ~/.ant/lib
curl -fsSL -o ~/.ant/lib/ivy.jar \
  https://repo1.maven.org/maven2/org/apache/ivy/ivy/2.6.0/ivy-2.6.0.jar

# confirm the installed versions
java -version
gradle -version
ant -version
```

```console
openjdk version "21.0.4" 2024-07-16
OpenJDK Runtime Environment Temurin-21.0.4+7 (build 21.0.4+7-LTS)
OpenJDK 64-Bit Server VM Temurin-21.0.4+7 (build 21.0.4+7-LTS, mixed mode, sharing)

------------------------------------------------------------
Gradle 9.4.0
------------------------------------------------------------

Apache Ant(TM) version 1.10.17 compiled on April 6 2026
```

> - `sdk install java 21.0.4-tem`, `sdk install gradle 9.4.0` and
>   `sdk install ant 1.10.17` install the tools under `~/.sdkman/candidates/`
>   and update `PATH` through the SDKMAN init script.
> - `mkdir -p ~/.ant/lib` creates the Ant user library directory.
> - `curl -fsSL -o ~/.ant/lib/ivy.jar ...` downloads the Ivy jar into that
>   directory.
> - `java -version`, `gradle -version` and `ant -version` print the installed
>   versions.
> - Ant has no wrapper and no dependency resolver of its own; the manual Ivy
>   installation is the Ant equivalent of the Gradle Wrapper and of Gradle's
>   built-in dependency management.

Port 8085 is used in the examples below to avoid a conflict with a service
already bound to 8080 on the machine used to capture the output. The
application default remains 8080.

---

## 3. Repository layout

```text
COGSI-2026-2027/
├── .gitignore
├── README.md                 (repository root)
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
    └── alternative/          (Bookstore application with Ant and Ivy)
        ├── build.xml
        ├── ivy.xml
        ├── scripts/{run.sh,run.bat}
        └── src/{main,test}/...
```

---

## 4. Operative guidelines

> Use your own group's private repository
> - Create a folder for each class assignment in the root of your repository,
>   where you should add the files specific to the assignment
>   (e.g., the application and the README.md file with the technical report)

```bash
# create the assignment folder in the repository root
mkdir -p CA1
```

> - `mkdir -p CA1` creates the folder that holds the two applications, the
>   alternative solution and this report; the resulting layout is shown in
>   section 3.

> Continue to operate Git via the command line
> - Create a branch for each feature and merge the completed feature into main

```bash
# create a feature branch from main, commit incrementally and push it
git checkout -b feature/ca1-part1-gradle-demo
git push -u origin feature/ca1-part1-gradle-demo
```

| Branch | PR | Content |
| --- | --- | --- |
| `feature/ca1-part1-gradle-demo` | #4 | Part 1 |
| `feature/ca1-part2-bookstore-gradle` | #5 | Part 2 |
| `feature/ca1-alternative-ant` | #8 | Alternative solution (Ant + Ivy) |
| `docs/ca1-report` | #9 | Technical report |

> - `git checkout -b <branch>` creates a feature branch from `main`, and
>   `git push -u origin <branch>` publishes it; the table lists the branch
>   used for each feature.
> - The work of each part was committed incrementally on its branch, and the
>   completed branches were merged into `main` through pull requests, so each
>   feature is reviewable as a unit.

> You will be using two different applications for this CA
> - Note: do not copy the .git folder from the app's original repository

```bash
# import the Gradle demo without its original history
cp -a /path/to/gradle_demo/. CA1/part1/
rm -rf CA1/part1/.git
```

> - `cp -a /path/to/gradle_demo/. CA1/part1/` copies the first application
>   (the Gradle demo) into the assignment folder.
> - `rm -rf CA1/part1/.git` removes the original repository metadata, as
>   required; the second application (the Bookstore) is imported the same way
>   in Part 2.

> Create issue(s) in GitHub for your main tasks

```bash
gh issue create --title "CA1 Part 1: Gradle demo application" --body "..."
gh issue create --title "CA1 Part 2: Migrate Bookstore Spring Boot app to Gradle" --body "..."
gh issue create --title "CA1 Alternative solution: compare build tools and implement an alternative" --body "..."
```

```console
https://github.com/Af-Oliveira/COGSI-2026-2027/issues/1
https://github.com/Af-Oliveira/COGSI-2026-2027/issues/2
https://github.com/Af-Oliveira/COGSI-2026-2027/issues/3
```

> - `gh issue create` creates one issue per main task, which allows each
>   feature to be tracked from the issue through the branch and the pull
>   request.

---

## 5. Technical report

> A technical report should be provided in a README.md file related to the
> assignment
> - You should use the Markdown syntax
> - No additional documentation (e.g., slides) is required — the README.md
>   must be sufficient, even if you present CA1
> - Include a self-evaluation for each team member on a 0 – 100% scale
>   representing their contribution. These percentages will be used to
>   determine individual grading

> Include a section dedicated to the description of the analysis, design, and
> implementation of the requirements of each part
> - Follow a tutorial style (i.e., it should be possible to reproduce the
>   assignment by following the instructions in the tutorial)
> - Include a description of the steps used to achieve the requirements
> - Include screenshots/output snippets where relevant
> - Include justifications for the options (when required)
> - Include two extra sections dedicated to the analysis and implementation of
>   the alternative solution

This file is the report, written in Markdown. Each exercise of the assignment
is quoted before the tutorial that implements it, so the coverage of the
requirements can be checked exercise by exercise. The self-evaluation required
by the guidelines is below.

| Team member | Contribution | Justification |
| --- | --- | --- |
| Ricardo Freitas | 50% | Part 2 conversion, the Ant alternative solution, and this report. |
| Af-Oliveira | 50% | Part 1 Gradle tasks, the Wrapper/toolchain study, and the Git/issue/PR workflow. |

Both members reviewed and validated the full assignment before submission.

---

## 6. Part 1 - First week

> The goal of the Part 1 of this assignment is to practice Gradle using a very
> simple example
> - https://github.com/lmpnogueira/cogsi/tree/main/build_tools
> - You will be working with this application in Part 1

The application is the Gradle demo: a multithreaded chat application with a
server, a client and a small text protocol. It is a multi-project build
composed of a root project (`gradle_demo`) and one subproject (`app`).

> You should start by pushing the Gradle demo application to your repository
> (in a folder for Part 1 of CA1)

```bash
# create the feature branch
git checkout -b feature/ca1-part1-gradle-demo

# import the application without its original Git history
mkdir -p CA1/part1
cp -a /path/to/gradle_demo/. CA1/part1/
rm -rf CA1/part1/.git

# record the import
git add CA1/part1
git commit -m "feat(ca1): import Gradle demo chat application (Part 1, initial v1.1.0)"
git push -u origin feature/ca1-part1-gradle-demo
```

> - `git checkout -b feature/ca1-part1-gradle-demo` creates the feature
>   branch.
> - `mkdir -p CA1/part1` creates the Part 1 folder.
> - `cp -a /path/to/gradle_demo/. CA1/part1/` copies the application into it.
> - `rm -rf CA1/part1/.git` removes the original history, as required.
> - `git add` and `git commit` record the import.
> - `git push -u origin feature/ca1-part1-gradle-demo` publishes the branch.

> Use tags to mark the versions of the application
> - You should use a pattern major.minor.revision (e.g., 1.1.0)
> - Tag the initial version as v1.1.0 and push the tag to the server

```bash
# tag the initial version and publish the tag
git tag -a v1.1.0 -m "Initial version of the Gradle demo application"
git push origin v1.1.0
```

> - `git tag -a v1.1.0` marks the initial version with the required
>   `major.minor.revision` pattern.
> - `git push origin v1.1.0` publishes the tag to the server.

> Read the instructions available in the README.md file and experiment with
> the application

```bash
# read the build instructions of the application README
sed -n '38,50p' README.md
```

```console
## Build

To build the project:

./gradlew clean build

This will:
- Compile the source code
- Run tests (if present)
- Generate the application JAR
- Resolve dependencies (Log4J, etc.)
```

```bash
# run the default entry point, which prints the application instructions
./gradlew run
```

```console
> Task :app:run

Welcome to "Multi-User Chat Application"!

You can run the server by entering the following command:

java -cp "app/build/libs/chat-server-1.0.jar:app/build/libs/lib/*" org.example.ChatServerApp <port number>

You can run the client by entering the following command:

java -cp "app/build/libs/chat-server-1.0.jar:app/build/libs/lib/*" org.example.ChatClientApp <server IP> <server port number>

Try this application by first running the server and then several clients.

BUILD SUCCESSFUL in 826ms
```

> - `sed -n '38,50p' README.md` prints the build section of the application
>   README, which documents the build command.
> - `./gradlew run` executes the default `run` task; the demo entry point
>   prints the commands to start the server and the clients.

> Use ./gradlew tasks to explore the available tasks and understand the
> project's build lifecycle

The Gradle Wrapper is used from the first command onwards. On the first run it
downloads the Gradle 9.4.0 distribution declared in
`gradle/wrapper/gradle-wrapper.properties` and caches it under `~/.gradle`.

```bash
# enter the project and list the available tasks
cd CA1/part1
./gradlew tasks
```

```console
> Task :tasks

------------------------------------------------------------
Tasks runnable from root project 'gradle_demo'
------------------------------------------------------------

Application tasks
-----------------
run - Runs this project as a JVM application

Build tasks
-----------
assemble - Assembles the outputs of this project.
backupSources - Copies the application source directories into a backup folder
backupZip - Archives the source backup produced by backupSources into a zip file
build - Assembles and tests this project.
...
cleanLogs - Deletes log files from the build directory
copyDependencies - Copies runtime dependencies to the application lib directory
...

DevOps tasks
------------
runClient - Launches the chat client and connects it to a chat server
runServer - Launches the chat server on a configurable port
...
```

> - `./gradlew tasks` executes the built-in `tasks` task and prints the task
>   list grouped by the `group` property; `runClient` and `runServer` appear
>   under "DevOps tasks" because their registration sets `group = 'DevOps'`.

> Use ./gradlew dependencies to inspect the dependency graph and understand how
> external libraries are resolved

```bash
# inspect the runtime dependency graph of the app subproject
./gradlew :app:dependencies --configuration runtimeClasspath
```

```console
> Task :app:dependencies

------------------------------------------------------------
Project ':app'
------------------------------------------------------------

runtimeClasspath - Runtime classpath of source set 'main'.
+--- org.apache.logging.log4j:log4j-api:2.26.1
\--- org.apache.logging.log4j:log4j-core:2.26.1
     \--- org.apache.logging.log4j:log4j-api:2.26.1

BUILD SUCCESSFUL in 699ms
```

> - `./gradlew :app:dependencies --configuration runtimeClasspath` resolves
>   the `runtimeClasspath` configuration of the `app` subproject and prints
>   the resulting graph; the output shows that `log4j-core` pulls `log4j-api`
>   transitively and that Gradle de-duplicates it to a single version
>   (`2.26.1`).

> Add a new runServer Gradle task to execute the server

The demo provides `runClient` (of type `JavaExec`) but no task to start the
server. A `runServer` task of type `JavaExec` was added to `app/build.gradle`,
with the port configurable through a Gradle property:

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

```bash
# start the server (the task blocks until the process is stopped)
./gradlew runServer -PserverPort=59001
```

```console
> Task :app:runServer
Starting ChatServerApp on port 59001
The chat server is running...
```

> - `tasks.register('runServer', JavaExec)` registers a task of the built-in
>   `JavaExec` type.
> - `classpath = sourceSets.main.runtimeClasspath` uses the compiled classes
>   plus the runtime dependencies.
> - `mainClass.set('org.example.ChatServerApp')` selects the server entry
>   point.
> - `providers.gradleProperty('serverPort')` reads the `-PserverPort`
>   command-line property with `59001` as the default, and `args(...)` passes
>   the port to the application.
> - `JavaExec` is used instead of `exec` because it runs the application with
>   the correct runtime classpath and registers the task inputs and outputs.

> Add a simple unit test and update the Gradle build script so that it can
> execute the test

JUnit 5 is declared in the version catalog and the `test` task is configured to
use the JUnit Platform.

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
logic (the greeting) and the construction of the server, avoiding sockets and
the Swing client so that the tests are deterministic:

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
# compile everything and run the unit tests
./gradlew clean test
```

```console
> Task :app:clean
> Task :app:processTestResources NO-SOURCE
> Task :app:processResources
> Task :app:compileJava
> Task :app:classes
> Task :app:compileTestJava
> Task :app:testClasses

> Task :app:test

AppTest > greeting mentions the multi-user chat application PASSED

AppTest > chat server can be instantiated with a port PASSED

BUILD SUCCESSFUL in 8s
```

> - `./gradlew clean test` runs `clean` and then the `test` task.
> - `test` compiles `src/test/java`, discovers the JUnit 5 tests through
>   `useJUnitPlatform()` and runs them; `testLogging` prints one line per test
>   event.
> - `junit-jupiter` is a `testImplementation` dependency and
>   `junit-platform-launcher` is `testRuntimeOnly`, because Gradle 9 requires
>   the launcher on the test runtime classpath to start the JUnit Platform.

> Add a new task of type Copy to be used to make a backup of the sources of
> the application
> - Copy only the application source directories (e.g., src/main and src/test)
>   into a backup folder

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
# create the source backup
./gradlew clean backupSources
```

```console
> Task :app:clean
> Task :app:backupSources
BUILD SUCCESSFUL in 681ms
```

```bash
# list the produced files
find app/build/backup/sources -type f | sort
```

```console
app/build/backup/sources/main/java/org/example/App.java
app/build/backup/sources/main/java/org/example/ChatClientApp.java
app/build/backup/sources/main/java/org/example/ChatClient.java
app/build/backup/sources/main/java/org/example/ChatServerApp.java
app/build/backup/sources/main/java/org/example/ChatServer.java
app/build/backup/sources/main/resources/log4j2.xml
app/build/backup/sources/test/java/org/example/AppTest.java
```

> - `tasks.register('backupSources', Copy)` registers a `Copy` task.
> - `from('src')` selects the source tree and the two `include` patterns
>   restrict it to `main/**` and `test/**`, so only application sources are
>   copied.
> - `into(layout.buildDirectory.dir(...))` sets the destination under the
>   build directory.
> - `find app/build/backup/sources -type f | sort` lists the seven files
>   produced by the copy.

> Add a new task of type Zip to be used to make an archive (i.e., a zip file)
> of the backup of the application
> - This task should depend on the execution of the backup task

A `backupZip` task of the built-in `Zip` type archives the backup. It declares
an explicit dependency on `backupSources`, so Gradle guarantees that the backup
exists before archiving.

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
# produce the archive (backupSources runs first through the dependency)
./gradlew backupZip
```

```console
> Task :app:backupSources UP-TO-DATE
> Task :app:backupZip
BUILD SUCCESSFUL in 676ms
```

```bash
# check the produced archive
ls -l app/build/distributions/
```

```console
-rw-rw-r-- 1 <user> <user> 7572 Sep 27 18:41 chat-server-sources-1.0.zip
```

> - `tasks.register('backupZip', Zip)` registers a `Zip` task.
> - `dependsOn(tasks.named('backupSources'))` adds the ordering dependency
>   between tasks, so invoking `backupZip` runs `backupSources` first; the
>   task is reported `UP-TO-DATE` because the backup already exists, which
>   shows Gradle's incremental execution.
> - `from(layout.buildDirectory.dir('backup/sources'))` selects the backup
>   directory.
> - `archiveBaseName` and `archiveVersion` compose the file name
>   (`chat-server-sources-1.0.zip`, where `1.0` comes from `appVersion` in
>   `gradle.properties`).
> - `destinationDirectory` places the archive under `build/distributions`.

> Explain how the Gradle Wrapper and the JDK Toolchain ensure the correct
> versions of Gradle and the Java Development Kit are used without requiring
> manual installation
> - In the root directory of the project, run ./gradlew javaToolchains and
>   explain the output

Two independent mechanisms guarantee the correct tool versions without manual
installation:

1. The Gradle Wrapper (`gradlew`, `gradlew.bat`, `gradle/wrapper/`) pins the
   Gradle version. `gradle-wrapper.properties` contains
   `distributionUrl=.../gradle-9.4.0-bin.zip`; the first invocation downloads
   that distribution into the Gradle user home and every subsequent invocation
   reuses it. Developers do not need Gradle installed globally.
2. The JDK toolchain pins the Java version used to compile and run the project.
   The `java { toolchain { languageVersion = JavaLanguageVersion.of(21) } }`
   block makes Gradle use a JDK 21 even if the default JDK is different.
   Combined with the `foojay-resolver-convention` plugin (applied in
   `settings.gradle`), Gradle can download the required JDK automatically.

```bash
# list the JDKs known to Gradle
./gradlew javaToolchains
```

```console
> Task :javaToolchains

 + Options
     | Auto-detection:     Enabled
     | Auto-download:      Enabled

 + Eclipse Temurin JDK 17 (17.0.20.1+1)
     | Location:           /home/<user>/.gradle/jdks/eclipse_adoptium-17-amd64-linux.2
     | Language Version:   17
     | Vendor:             Eclipse Temurin
     | Architecture:       amd64
     | Is JDK:             true
     | Detected by:        Auto-provisioned by Gradle

 + Eclipse Temurin JDK 21 (21.0.4+7-LTS)
     | Location:           /home/<user>/.sdkman/candidates/java/21.0.4-tem
     | Language Version:   21
     | Vendor:             Eclipse Temurin
     | Architecture:       amd64
     | Is JDK:             true
     | Detected by:        Current JVM
```

> - `./gradlew javaToolchains` prints the toolchain detection report.
> - The auto-provisioned Temurin 17 entry shows Gradle downloading a JDK
>   through the Foojay resolver when a requested version is not installed
>   locally.
> - The Temurin 21 entry is the SDKMAN installation detected as the current
>   JVM; the build requests Java 21, so Gradle selects it and the build does
>   not depend on the JDK installed on the developer machine.

> At the end of the assignment mark your commit with the milestone tag
> ca1-part1

At the end of Part 1 the commit was tagged with the milestone `ca1-part1`:

```bash
# tag and publish the Part 1 milestone
git tag -a ca1-part1 -m "CA1 Part 1 milestone"
git push origin ca1-part1
```

> - `git tag -a ca1-part1` creates the milestone tag.
> - `git push origin ca1-part1` publishes it.

---

## 7. Part 2 - Second week

> The goal of Part 2 of this assignment is to convert the Bookstore Spring Boot
> application to Gradle (instead of Maven)
> - On an empty folder for Part 2 of CA1 use the gradle init command to create
>   a Gradle project
> - Replace the generated application source structure with the Bookstore
>   application source code, adapting the Gradle project layout as needed

The application is the Bookstore REST API (Spring Boot, Spring Data JPA, H2,
Spring HATEOAS), originally built with Maven (`pom.xml`). An empty folder was
created and initialised with the Gradle `init` task:

```bash
# create the feature branch and the project folder
git checkout -b feature/ca1-part2-bookstore-gradle
mkdir -p CA1/part2
cd CA1/part2

# generate a Java application build
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

> - `git checkout -b feature/ca1-part2-bookstore-gradle` creates the feature
>   branch and `mkdir -p CA1/part2` the Part 2 folder.
> - `gradle init` generates the Wrapper, `settings.gradle`, `build.gradle`,
>   `gradle/libs.versions.toml` and a sample `App`/`AppTest`.
> - `--type java-application` selects the Java application template, `--dsl
>   groovy` the Groovy DSL and `--test-framework junit-jupiter` the JUnit 5
>   test framework.
> - `--package`/`--project-name` set the identity of the project,
>   `--no-split-project` a single-module layout and `--java-version 21` the
>   Java version.
> - `--use-defaults` accepts the remaining defaults.

The generated sample sources were removed and the Bookstore sources were copied
in, keeping the standard Maven/Gradle source layout (`src/main/java`,
`src/main/resources`), so no package or import changes were required:

```bash
# replace the generated sample with the Bookstore sources
rm -rf app
mkdir -p src
cp -a /path/to/bookstore/src/. src/
```

> - `rm -rf app` deletes the generated sample module.
> - `mkdir -p src` creates the source root.
> - `cp -a /path/to/bookstore/src/. src/` copies the Bookstore sources into
>   it.

> Make sure that all needed dependencies and plugins are added to your Gradle
> build script
> - Prefer using libs.versions.toml when managing dependencies

Both plugins and dependencies are declared in the version catalog
`gradle/libs.versions.toml`:

```toml
[versions]
spring-boot = "4.1.1"

[libraries]
spring-boot-dependencies = { module = "org.springframework.boot:spring-boot-dependencies", version.ref = "spring-boot" }
spring-boot-starter-web = { module = "org.springframework.boot:spring-boot-starter-web" }
spring-boot-starter-data-jpa = { module = "org.springframework.boot:spring-boot-starter-data-jpa" }
spring-boot-starter-hateoas = { module = "org.springframework.boot:spring-boot-starter-hateoas" }
spring-boot-starter-actuator = { module = "org.springframework.boot:spring-boot-starter-actuator" }
spring-boot-starter-test = { module = "org.springframework.boot:spring-boot-starter-test" }
junit-platform-launcher = { module = "org.junit.platform:junit-platform-launcher" }
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

> - The `[versions]`, `[libraries]` and `[plugins]` sections of the version
>   catalog centralise the coordinates; `libs.spring.boot.starter.web` and the
>   other aliases are generated by Gradle from the catalog.
> - `alias(libs.plugins.spring.boot)` applies the Spring Boot plugin.
> - `implementation platform(libs.spring.boot.dependencies)` imports the BOM,
>   so the starter dependencies resolve to the versions managed by Spring Boot
>   4.1.1.
> - The original `pom.xml` used Spring Boot 3.3.0; the Spring Boot Gradle
>   plugin only supports Gradle 9 from Spring Boot 4.x (the 3.x plugin calls
>   the removed `CopyProcessingSpec.getDirMode()` API), so the application was
>   moved to Spring Boot 4.1.1 to keep one Gradle 9.4.0 Wrapper across both
>   parts. The only source adaptation required was in the integration test
>   (see the integration test exercise).

> Build and run the application with ./gradlew bootRun
> - Use your browser at http://localhost:8080 to test the application

```bash
# start the application on port 8085
./gradlew bootRun --args='--server.port=8085'
```

```console
> Task :bootRun
Tomcat started on port 8085 (http) with context path '/'
Started BookstoreApplication in 3.258 seconds (process running for 3.522)
```

```bash
# query the API from another terminal
curl -s http://localhost:8085/books
```

```json
[{"author":"Robert C. Martin","id":1,"price":30.0,"title":"Clean Code"},
 {"author":"Joshua Bloch","id":2,"price":40.0,"title":"Effective Java"}]
```

> - `./gradlew bootRun` runs the application through the Spring Boot plugin.
> - `--args='--server.port=8085'` forwards the Spring Boot argument that
>   changes the HTTP port; the default is 8080, which is the port the exercise
>   uses for the browser test (`http://localhost:8080`).
> - `curl -s http://localhost:8085/books` is the command-line equivalent of
>   opening the API in the browser; it calls the `/books` endpoint and returns
>   the seeded data, which confirms that the application is serving the REST
>   API.

> Create a custom task named deployToDev that orchestrates the following steps:
> 1. Use the built-in Delete task type to clean out a specific, deployment
>    directory (e.g., build/deployment/dev)
> 2. Use the built-in Copy task type to move the main application artifact
>    into the deployment directory
> 3. Use another Copy task to place a subset of external dependencies (e.g.,
>    only the JARs required at runtime) into a subfolder of the deployment
>    directory (e.g., build/deployment/dev/lib)
> 4. Use a final Copy task to copy the configuration files (e.g.,
>    src/main/resources/*.properties) to the deployment directory. Use the
>    ReplaceTokens filter to replace a placeholder with a build property, such
>    as the current build timestamp or project version

The four steps are implemented by four tasks registered in `build.gradle`,
orchestrated by `deployToDev`:

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

tasks.named('copyAppArtifact').configure { mustRunAfter tasks.named('cleanDeployment') }
tasks.named('copyRuntimeDependencies').configure { mustRunAfter tasks.named('cleanDeployment') }
tasks.named('copyConfigurationWithTokens').configure { mustRunAfter tasks.named('cleanDeployment') }
```

The placeholder tokens are declared in `application.properties`:

```properties
app.build.timestamp=@BUILD_TIMESTAMP@
app.version=@APP_VERSION@
```

The `ReplaceTokens` filter replaces `@TOKEN@` occurrences, so the deployed
configuration contains the build timestamp and the project version.

```bash
# assemble the development deployment
./gradlew deployToDev
```

```console
> Task :cleanDeployment
> Task :copyConfigurationWithTokens
> Task :bootJar UP-TO-DATE
> Task :copyRuntimeDependencies
> Task :copyAppArtifact
> Task :deployToDev
BUILD SUCCESSFUL in 1s
```

```bash
# inspect the deployment directory
find build/deployment/dev -maxdepth 1 | sort
grep -E 'app\.(build|version)' build/deployment/dev/application.properties
```

```console
build/deployment/dev
build/deployment/dev/application.properties
build/deployment/dev/bookstore-1.0.0.jar
build/deployment/dev/lib

app.build.timestamp=2026-09-27 18:33:22
app.version=1.0.0
```

> - `tasks.register('cleanDeployment', Delete)` uses the built-in `Delete`
>   type to remove the previous deployment.
> - `copyAppArtifact` depends on `bootJar` and consumes its `archiveFile`
>   output, so the executable jar is always produced before the copy.
> - `copyRuntimeDependencies` selects only `*.jar` from
>   `configurations.runtimeClasspath` and copies them into `lib/`.
> - `copyConfigurationWithTokens` applies `ReplaceTokens` with the
>   `BUILD_TIMESTAMP` and `APP_VERSION` tokens, which are written to
>   `application.properties` (`ReplaceTokens` is imported from
>   `org.apache.tools.ant.filters` at the top of the build script).
> - `deployToDev` depends on the four steps, and the copies are declared
>   `mustRunAfter` the `Delete`, so the deployment directory is cleaned before
>   anything is copied into it.
> - `find build/deployment/dev -maxdepth 1` and `grep` show the resulting tree
>   and the replaced configuration values.

> Create a custom task that depends on the installDist task, running the
> application using the generated distribution scripts
> - Define the executable script based on the operating system

Two tasks are involved. First, `installDist` (from the `application` plugin)
generates a standard distribution with start scripts. Then a custom
`runFromDistribution` task depends on `installDist` and executes the script
that matches the operating system.

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
# generate the distribution
./gradlew installDist
```

```console
> Task :jar
> Task :startScripts
> Task :installDist
BUILD SUCCESSFUL in 1s
```

The distribution contains the OS-specific scripts
(`build/install/bookstore/bin/bookstore` and `bookstore.bat`), the thin jar and
the runtime dependencies in `lib/`.

```bash
# run the generated script on port 8085
./gradlew runFromDistribution -PserverPort=8085
```

```console
> Task :runFromDistribution
Running distribution script: .../build/install/bookstore/bin/bookstore
Tomcat started on port 8085 (http) with context path '/'
Started BookstoreApplication in 3.98 seconds
```

> - `./gradlew installDist` runs the `application` plugin tasks that produce
>   the distribution.
> - `runFromDistribution` depends on `installDist` and selects the executable
>   from `os.name` (`bookstore.bat` on Windows, `bookstore` otherwise), which
>   makes the task portable.
> - `-PserverPort=8085` sets the Gradle property that the task exports as the
>   `SERVER_PORT` environment variable, which Spring Boot binds to
>   `server.port`.

> Create a custom task that depends on the javadoc task
> - It should generate the Javadoc for your project, and then package the
>   generated documentation into a zip file

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
# generate and package the Javadoc
./gradlew javadocZip
```

```console
> Task :javadoc
> Task :javadocZip
BUILD SUCCESSFUL in 2s
```

```bash
# inspect the archive
unzip -l build/distributions/bookstore-javadoc-1.0.0.zip | tail -3
```

```console
---------                     -------
   634690                     75 files
```

> - `tasks.register('javadocZip', Zip)` registers the archive task, and
>   `dependsOn(tasks.named('javadoc'))` guarantees that the documentation is
>   generated first.
> - `from(tasks.named('javadoc'))` consumes the declared output directory of
>   the `javadoc` task, so the archive always reflects the latest
>   documentation.
> - `unzip -l` lists the archive and shows the 75 packaged files.

> Create a new source set for integration tests
> - Add a simple test and the needed dependencies and tasks to run the test

The default `test` source set is kept for fast unit tests and a new
`integrationTest` source set is added for tests that boot the full Spring
context.

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

The test boots the application on a random port and calls the real HTTP API.
Spring Boot 4 removed `TestRestTemplate`, so the modern `RestTestClient` is
used:

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
# run the integration tests
./gradlew integrationTest
```

```console
> Task :compileIntegrationTestJava
> Task :integrationTestClasses
> Task :integrationTest
BUILD SUCCESSFUL in 7s
```

> - The `sourceSets` block adds `integrationTest` with its own source
>   directories and extends the test classpaths, so the integration tests see
>   the main classes and the test dependencies.
> - The `configurations` block makes `integrationTestImplementation` and
>   `integrationTestRuntimeOnly` inherit from the corresponding test
>   configurations.
> - `tasks.register('integrationTest', Test)` runs that source set with the
>   JUnit Platform, and `shouldRunAfter` orders it after the unit tests.
> - `tasks.named('check') { dependsOn ... }` makes `./gradlew build` run both
>   suites.
> - The test itself boots the application with
>   `@SpringBootTest(webEnvironment = RANDOM_PORT)` and uses `RestTestClient`
>   to call `/books` and `/actuator/health`.

> At the end of the assignment mark your commit with the milestone tag
> ca1-part2

```bash
# tag and publish the Part 2 milestone
git tag -a ca1-part2 -m "CA1 Part 2 milestone"
git push origin ca1-part2
```

> - `git tag -a ca1-part2` creates the milestone tag.
> - `git push origin ca1-part2` publishes it.

---

## 8. Analysis of alternative solutions

> Present alternative technological solutions for the build automation tool
> (i.e., not based on Gradle)

Four non-Gradle build tools were analysed: Apache Maven, Apache Ant with
Apache Ivy, Bazel and Mill.

**Apache Maven.** A declarative, lifecycle-based build tool. The build is
described in an XML `pom.xml`. Maven defines fixed phases (`validate`,
`compile`, `test`, `package`, `verify`, `install`, `deploy`) and binds plugin
goals to them. Extensibility is achieved by adding plugins or writing new Maven
plugins. It has a very large, mature ecosystem and a
convention-over-configuration model. It has no native wrapper (the community
`maven-wrapper` exists) and no general-purpose incremental cache:
incrementality is delegated to individual plugins. Maven is the tool the
Bookstore originally used, so a Maven implementation would reproduce the
starting point rather than an alternative design.

**Apache Ant with Apache Ivy.** An imperative, script-based build tool. The
build is an XML file with `targets` and `tasks`; the developer wires the
execution order explicitly with `depends`. It has no built-in conventions and
no dependency management: dependencies are resolved by Apache Ivy from
`ivy.xml`, using the same Maven repositories and metadata as Gradle. New
functionality is added by composing the built-in tasks, by writing custom Ant
tasks in Java, or by invoking external tools. It is well suited to procedural,
non-standard builds and requires more boilerplate than Gradle or Maven.

**Bazel.** A hermetic, multi-language build system using Starlark
(`BUILD`/`.bzl`) files. It models the build as a dependency graph of targets
and provides content-addressed caching, sandboxing and remote execution.
Incrementality and caching are stronger than Gradle's for large polyglot
repositories. Extensibility is through rule sets (for example
`rules_jvm_external` for Maven dependencies, `rules_spring` for Spring Boot).
The trade-off is a steeper learning curve and more setup for a single Spring
Boot application.

**Mill.** A newer JVM build tool whose build is a set of Scala modules and
tasks. It targets fast, incremental JVM builds with a Scala/Java-friendly model
and supports dependency management directly. Extensibility is through Scala
code. It fits JVM-centric projects but has a smaller ecosystem than Maven or
Gradle.

> Analyze how the alternative solutions compare to your base solution
> - Present how the alternative tools compare to Gradle regarding build
>   automation features
>   - E.g., compare how the build tools can be extended with new functionality
>     (i.e., new plugins or new tasks)

| Aspect | Gradle (base) | Maven | Ant + Ivy | Bazel | Mill |
| --- | --- | --- | --- | --- | --- |
| Model | Task graph (DAG) | Fixed lifecycle phases | Imperative targets | Target graph (hermetic) | Task modules (Scala) |
| Build language | Groovy/Kotlin DSL + plugins | XML `pom.xml` | XML build file + `ivy.xml` | Starlark | Scala |
| Extending with new tasks/plugins | `tasks.register`, custom task types, plugins | New plugin goals bound to phases | New targets, custom Ant tasks, task composition | Starlark rules | Scala modules/tasks |
| Dependency management | Built-in, version catalogs, BOM | Built-in, BOM import | Ivy, Maven repositories, configurations | `rules_jvm_external` | Built-in |
| Version pinning without install | Gradle Wrapper | `maven-wrapper` (community) | Manual (Ant + Ivy installation) | Bazelisk | Mill wrapper |
| Incremental/caching | Up-to-date checks + build cache | Plugin-dependent | Manual | Content-addressed, remote | Incremental tasks |
| Learning curve | Moderate | Low/Moderate | Low | High | Moderate |
| Best fit | Flexible JVM/Android/polyglot | Conventional JVM | Unusual/procedural builds | Large polyglot monorepos | JVM-centric builds |

> Describe how the alternative tools could be used (i.e., only the design of
> the solution) to solve the same goals as presented for this assignment

- **Maven.** Define the deployment as plugin executions bound to phases: the
  `maven-dependency-plugin` (`copy-dependencies`) for the runtime JARs, the
  `maven-resources-plugin` (`copy-resources` with filtering) or the
  `maven-antrun-plugin` (`ReplaceTokens`) for the configuration, the
  `spring-boot-maven-plugin` for the executable artifact, and an
  `antrun`/`assembly` step for the distribution and the Javadoc zip.
  Integration tests run through `maven-failsafe-plugin` (`*IT.java`). Maven has
  no named tasks, so the `deployToDev` equivalent is a profile
  (`mvn -Pdeploy-dev package`).
- **Ant + Ivy.** Write targets `clean-deployment`, `copy-artifact`,
  `copy-libs`, `copy-config` (with a `filterset`), `jar`, `zip-dist` and
  `run-dist`, wire them with `depends`, and resolve dependencies with Ivy.
  Versions come from `ivy.xml`; the JUnit Platform is executed through the Ant
  `junitlauncher` task. This is the implemented design.
- **Bazel.** Declare `java_library`, `java_binary` and a `springboot` rule,
  manage dependencies with `rules_jvm_external` (pinned Maven coordinates in
  `MODULE.bazel`), add integration tests as `java_test` with a `sh_test`
  runner, and use `genrule`/`pkg_zip` for the distribution and the Javadoc
  zip. Caching and reproducibility are excellent, but the setup cost for one
  service is high.
- **Mill.** Define modules and tasks in Scala: a build module producing the
  assembly, tasks for the deployment copy/filter, and a test module using
  `testForked`. Version pinning uses `ivyDeps`.

---

## 9. Implementation of the alternative solution

> To achieve the requirements for the highest grade, implement one of the
> alternative designs proposed in the previous item

The Ant design was implemented under `CA1/alternative/`. Ant is a non-Gradle
tool with a different execution model (imperative targets instead of a task
graph) and it is not the tool the Bookstore originally used, so it exercises a
real migration. The implementation reproduces every Part 2 goal:

| Goal (Gradle) | Ant target |
| --- | --- |
| `build` | `ant build` |
| `bootRun` | `ant run` |
| `integrationTest` | `ant integration-test` |
| `deployToDev` | `ant deploy-to-dev` |
| `runFromDistribution` | `ant run-from-distribution` |
| `javadocZip` | `ant javadoc-zip` |

The dependency descriptor (`ivy.xml`) resolves the same libraries that the
Gradle build declares in `gradle/libs.versions.toml`. The Spring Boot starters
import the `spring-boot-dependencies` BOM, so their transitive dependencies are
versioned by the BOM; only dependencies that Spring Boot manages but does not
pull transitively need an explicit revision.

```xml
<ivy-module version="2.0">

    <info organisation="com.example" module="bookstore" revision="1.0.0"/>

    <configurations>
        <conf name="compile" visibility="public" description="Compilation of the application sources"/>
        <conf name="runtime" extends="compile" visibility="public" description="Execution of the application"/>
        <conf name="test" extends="runtime" visibility="public" description="Compilation and execution of the integration tests"/>
    </configurations>

    <dependencies>
        <dependency org="org.springframework.boot" name="spring-boot-starter-web" rev="4.1.1"/>
        <dependency org="org.springframework.boot" name="spring-boot-starter-data-jpa" rev="4.1.1"/>
        <dependency org="org.springframework.boot" name="spring-boot-starter-hateoas" rev="4.1.1"/>
        <dependency org="org.springframework.boot" name="spring-boot-starter-actuator" rev="4.1.1"/>

        <dependency org="com.h2database" name="h2" rev="2.4.240" conf="runtime->default(*)"/>

        <dependency org="org.springframework.boot" name="spring-boot-starter-test" rev="4.1.1" conf="test->default(*)"/>
        <dependency org="org.junit.platform" name="junit-platform-launcher" rev="6.0.3" conf="test->default(*)"/>
    </dependencies>

</ivy-module>
```

> - The `<configurations>` element defines three configurations that mirror
>   Gradle's source-set classpaths: `compile`, `runtime` (which extends
>   `compile`) and `test` (which extends `runtime`).
> - The four starters are declared without a `conf` attribute and therefore
>   contribute to all configurations.
> - `h2` is restricted to `runtime` and the test stack to `test`; the
>   `->default(*)` mapping is required because the artifact of a module lives
>   in its `master` configuration, and `default(*)` includes `master`.
> - The revisions `2.4.240` and `6.0.3` are the versions managed by the Spring
>   Boot BOM for `h2` and the JUnit Platform launcher.

```bash
# enter the alternative project and resolve the three classpaths
cd CA1/alternative
ant resolve
```

```console
resolve:
[ivy:cachepath] :: Apache Ivy 2.6.0 - 20260712075753 :: https://ant.apache.org/ivy/ ::
[ivy:cachepath] :: resolving dependencies :: com.example#bookstore;1.0.0
...
	---------------------------------------------------------------------
	|                  |            modules            ||   artifacts   |
	|       conf       | number| search|dwnlded|evicted|| number|dwnlded|
	---------------------------------------------------------------------
	|      compile     |   99  |   0   |   0   |   8   ||   99  |   0   |
	---------------------------------------------------------------------
	|      runtime     |  100  |   0   |   0   |   8   ||  100  |   0   |
	---------------------------------------------------------------------
	|       test       |  129  |   0   |   0   |   14  ||  123  |   0   |
	---------------------------------------------------------------------

BUILD SUCCESSFUL
```

> - `ant resolve` runs the `resolve` target, which calls `ivy:cachepath`
>   three times to build the `compile`, `runtime` and `test` classpath
>   references from `ivy.xml`.
> - The resolution report shows 99 modules for `compile`, 100 for `runtime`
>   (the extra module is `h2`) and 129 for `test` (the test stack plus the
>   launcher); the `evicted` column lists the modules replaced by conflict
>   resolution.

The build file (`build.xml`) declares the properties and the targets that
reproduce the Gradle tasks. The build and test targets:

```xml
<target name="compile" depends="resolve" description="Compiles the application sources and copies the resources">
    <mkdir dir="${classes.dir}"/>
    <javac srcdir="${src.dir}"
           destdir="${classes.dir}"
           classpathref="compile.classpath"
           release="${java.release}"
           includeantruntime="false"
           encoding="UTF-8"
           debug="true"/>
    <copy todir="${classes.dir}" overwrite="true">
        <fileset dir="${resources.dir}"/>
    </copy>
</target>

<target name="integration-test" depends="compile-tests" description="Runs the integration tests with the JUnit Platform launcher">
    <mkdir dir="${test.results.dir}"/>
    <junitlauncher printSummary="true">
        <classpath>
            <path refid="test.classpath"/>
            <pathelement location="${classes.dir}"/>
            <pathelement location="${test.classes.dir}"/>
            <pathelement location="${resources.dir}"/>
        </classpath>
        <testclasses outputdir="${test.results.dir}">
            <fileset dir="${test.classes.dir}" includes="**/*IT.class"/>
            <listener type="legacy-plain" sendSysOut="true"/>
            <fork includeJUnitPlatformLibraries="false">
                <jvmarg value="-Dfile.encoding=UTF-8"/>
            </fork>
        </testclasses>
    </junitlauncher>
</target>

<target name="build" depends="jar, integration-test" description="Compiles, tests and packages the application"/>
```

The deployment, run and documentation targets:

```xml
<target name="deploy-to-dev" depends="jar" description="Assembles the development deployment, replacing configuration tokens">
    <tstamp>
        <format property="build.timestamp" pattern="yyyy-MM-dd HH:mm:ss"/>
    </tstamp>

    <delete dir="${deployment.dir}"/>
    <mkdir dir="${deployment.dir}"/>
    <copy file="${jar.file}" todir="${deployment.dir}"/>

    <ivy:retrieve conf="runtime"
                  pattern="${dependency.dir}/[artifact]-[revision](-[classifier]).[ext]"/>
    <mkdir dir="${deployment.dir}/lib"/>
    <copy todir="${deployment.dir}/lib">
        <fileset dir="${dependency.dir}" includes="*.jar"/>
    </copy>

    <copy todir="${deployment.dir}" overwrite="true" filtering="true">
        <fileset dir="${resources.dir}" includes="*.properties"/>
        <filterset>
            <filter token="BUILD_TIMESTAMP" value="${build.timestamp}"/>
            <filter token="APP_VERSION" value="${app.version}"/>
        </filterset>
    </copy>

    <copy todir="${deployment.dir}/bin">
        <fileset dir="scripts"/>
    </copy>
    <chmod file="${deployment.dir}/bin/run.sh" perm="755"/>
    <mkdir dir="${distributions.dir}"/>
    <zip destfile="${distributions.dir}/${app.name}-dev-distribution.zip" basedir="${deployment.dir}"/>
</target>

<target name="run-from-distribution" depends="deploy-to-dev" description="Runs the application with the generated start script">
    <condition property="distribution.script"
               value="${deployment.dir}/bin/run.bat"
               else="${deployment.dir}/bin/run.sh">
        <os family="windows"/>
    </condition>
    <exec executable="${distribution.script}" failonerror="true">
        <env key="SERVER_PORT" value="${server.port}"/>
    </exec>
</target>

<target name="javadoc-zip" depends="javadoc" description="Packages the generated Javadoc into a zip file">
    <mkdir dir="${distributions.dir}"/>
    <zip destfile="${distributions.dir}/${app.name}-javadoc-${app.version}.zip" basedir="${javadoc.dir}"/>
</target>
```

> - `compile` uses the `javac` task with the Ivy `compile.classpath`
>   reference and copies `src/main/resources` into the classes directory.
> - `integration-test` uses the `junitlauncher` task with the test classpath,
>   selects the `*IT.class` classes, prints the summary and forks a JVM
>   (`includeJUnitPlatformLibraries="false"` keeps the classpath defined by
>   the target instead of the Ant runtime).
> - `build` composes `jar` and `integration-test`.
> - In `deploy-to-dev`, `tstamp` produces the build timestamp, `delete` and
>   `mkdir` clean and create the deployment directory, `copy` moves the jar,
>   `ivy:retrieve` downloads the runtime artifacts and the second `copy`
>   places them in `lib`, the filtered `copy` replaces the tokens through a
>   `filterset`, and `zip` archives the result.
> - `run-from-distribution` selects `run.bat` or `run.sh` with
>   `condition`/`os` and executes it with `exec`, exporting `SERVER_PORT`.
> - `javadoc-zip` archives the Javadoc output directory.

The start scripts assemble the classpath from the thin jar and the `lib`
directory:

```sh
#!/bin/sh
set -e

DIR=$(cd "$(dirname "$0")/.." && pwd)
JAR=$(ls "$DIR"/bookstore-*.jar 2>/dev/null | head -n 1)

if [ -z "$JAR" ]; then
    echo "No application jar found in $DIR" >&2
    exit 1
fi

exec java -cp "$JAR:$DIR/lib/*" com.example.bookstore.BookstoreApplication "$@"
```

> - `DIR=$(cd "$(dirname "$0")/.." && pwd)` resolves the deployment directory
>   from the script location.
> - `JAR=$(ls "$DIR"/bookstore-*.jar ...)` locates the application jar, and
>   the guard exits with an error if it is missing.
> - `exec java -cp "$JAR:$DIR/lib/*" com.example.bookstore.BookstoreApplication`
>   starts the application with the jar plus every runtime JAR in `lib/`.
> - Ant has no built-in Spring Boot repackaging, so the deployed artifact is a
>   plain jar and the start script assembles the classpath; the Gradle build
>   packages the same dependencies inside the executable `bootJar`.

```bash
# compile, package and run the integration tests
ant clean build
```

```console
compile:
    [javac] Compiling 25 source files to .../build/classes

jar:
      [jar] Building jar: .../build/libs/bookstore-1.0.0.jar

integration-test:
[junitlauncher] Running com.example.bookstore.BookstoreApiIntegrationTestIT
[junitlauncher] Tests run: 2, Failures: 0, Aborted: 0, Skipped: 0, Time elapsed: 5.038 sec

build:

BUILD SUCCESSFUL
```

> - `ant clean build` runs the `clean` target (deletes `build/`) and the
>   `build` target.
> - `build` depends on `jar` and `integration-test`: the `javac` task
>   compiles the 25 application sources and `jar` packages them into
>   `build/libs/bookstore-1.0.0.jar`.
> - `junitlauncher` runs the two integration tests against the Spring context
>   and prints the summary.

```bash
# run the application from the compiled classes on port 8085
ant run -Dserver.port=8085
```

```console
run:
     [java] ... Tomcat started on port 8085 (http) with context path '/'
     [java] ... Started BookstoreApplication in 3.926 seconds
```

```bash
# query the API from another terminal
curl -s http://localhost:8085/books
```

```json
[{"author":"Robert C. Martin","id":1,"price":30.0,"title":"Clean Code"},
 {"author":"Joshua Bloch","id":2,"price":40.0,"title":"Effective Java"}]
```

> - `ant run` executes the `run` target, which depends on `compile` and
>   starts the main class with the `java` task using the `runtime.classpath`
>   reference.
> - `-Dserver.port=8085` overrides the `server.port` property, and the target
>   passes it to Spring Boot as `--server.port=8085`.

```bash
# assemble the development deployment
ant deploy-to-dev
```

```console
deploy-to-dev:
[ivy:retrieve] 100 artifacts copied, 0 already retrieved (54306kB/63ms)
     [copy] Copying 100 files to .../build/deployment/dev/lib
     [copy] Copying 1 file to .../build/deployment/dev
     [copy] Copying 2 files to .../build/deployment/dev/bin
      [zip] Building zip: .../build/distributions/bookstore-dev-distribution.zip
BUILD SUCCESSFUL
```

```bash
# inspect the deployment directory and the replaced configuration
find build/deployment/dev -maxdepth 1 | sort
grep -E 'app\.(build|version)' build/deployment/dev/application.properties
```

```console
build/deployment/dev
build/deployment/dev/application.properties
build/deployment/dev/bin
build/deployment/dev/bookstore-1.0.0.jar
build/deployment/dev/lib

app.build.timestamp=2026-09-27 18:28:29
app.version=1.0.0
```

> - `ant deploy-to-dev` runs the deployment target shown above.
> - `ivy:retrieve` resolves and downloads the 100 runtime artifacts, and the
>   first `copy` places them in `lib/`.
> - The second `copy` copies the application jar, and the filtered copy
>   produces `application.properties` with the tokens replaced.
> - The scripts are copied into `bin/`, and `zip` packages the whole
>   directory into `bookstore-dev-distribution.zip`.

```bash
# run the generated start script on port 8085
ant run-from-distribution -Dserver.port=8085
```

```console
run-from-distribution:
     [exec] ... Tomcat started on port 8085 (http) with context path '/'
     [exec] ... Started BookstoreApplication in 4.272 seconds
```

> - `ant run-from-distribution` depends on `deploy-to-dev`, selects the
>   script for the operating system and executes it, exporting
>   `SERVER_PORT=8085`.
> - The output is produced by the `run.sh` script, which starts the
>   application from the deployment directory.

```bash
# generate the Javadoc and package it
ant javadoc-zip
```

```console
javadoc:
  [javadoc] Generating Javadoc

javadoc-zip:
      [zip] Building zip: .../build/distributions/bookstore-javadoc-1.0.0.zip
BUILD SUCCESSFUL
```

```bash
# inspect the archive
unzip -l build/distributions/bookstore-javadoc-1.0.0.zip | tail -3
```

```console
---------                     -------
   209885                     66 files
```

> - `ant javadoc-zip` depends on the `javadoc` target, which runs the
>   `javadoc` task over `src/main/java` with the compile classpath and
>   generates the documentation under `build/reports/apidocs`.
> - The `zip` task archives it into `bookstore-javadoc-1.0.0.zip`.

---

## 10. Reflection

> 5 – achieves completely the requirements; justifies options; analyzes
> alternatives; implements one alternative and reflects on the differences

The most visible difference between the two implemented solutions is the
execution model. Gradle exposes a task graph: `deployToDev` is a first-class,
named task that depends on other tasks and can be invoked directly
(`./gradlew deployToDev`). Ant has no task graph; `deploy-to-dev` is a target
whose steps run sequentially in the order they are written, and the ordering
between targets is encoded in `depends` and in the order of the tasks inside a
target. This makes the Gradle build easier to compose (for example,
`copyAppArtifact` reuses the declared `bootJar` output and is skipped when up
to date) and the Ant build easier to read as a procedural script.

Extensibility follows from the same difference. In Gradle, new behaviour is a
new task type or a plugin (`Copy`, `Zip`, `JavaExec`, the Spring Boot plugin);
the build script configures them. In Ant, new behaviour is a new target that
composes built-in tasks, or a custom Java class. Ant's `junitlauncher` task,
for example, is a built-in task that embeds the JUnit Platform launcher, while
Gradle's `Test` task integrates the platform natively. For Spring Boot
packaging, Gradle has a first-class plugin that produces the executable
`bootJar`; in Ant the artifact is a plain jar and the start script assembles
the classpath from `lib/`.

Dependency management is comparable in result and different in mechanism.
Gradle declares dependencies in `libs.versions.toml` and imports the Spring
Boot BOM, which provides the versions; the resolution output shows the same
libraries in both builds. Ant delegates resolution to Ivy, which reads
`ivy.xml`, understands the same Maven metadata (including the BOM imported by
the starters) and resolves the same graph; the configurations (`compile`,
`runtime`, `test`) map to Gradle's source-set classpaths. Conflict resolution
is explicit in both outputs (the `evicted` entries in the Ivy report).

Reproducibility is where Gradle has a structural advantage. The Wrapper is
committed with the project, so the exact Gradle version needs no installation,
and the JDK toolchain pins the Java version with automatic download through
Foojay. Ant has no wrapper: Ant and Ivy must be installed and kept in sync
manually, and there is no toolchain mechanism, so the build depends on the JDK
on `PATH`. On the other hand, the Ant build is a plain XML script with no
daemon, no cache and no hidden state, which makes its execution easy to
predict. Bazel is the strongest alternative for reproducibility and caching,
at the cost of significantly more setup; Mill sits between Gradle and Bazel in
complexity. For a single Spring Boot service, Ant and Maven are the lightest
alternatives, and Ant is the one that shows a genuinely different model.

Finally, the conversion from Maven to Gradle was not purely mechanical. The
Spring Boot 3.3.0 plugin used by the original `pom.xml` does not support
Gradle 9 (it calls the removed `CopyProcessingSpec.getDirMode()` API), so the
application was moved to Spring Boot 4.1.1. Keeping a single Gradle version
across both parts therefore required upgrading the framework, which is a
concrete example of a trade-off imposed by the tooling ecosystem.

---

## 11. Conclusion

All requirements of CA1 were implemented and verified:

- Part 1: the Gradle demo chat application was imported and tagged `v1.1.0`;
  the task list and dependency graph were inspected; the `runServer` task, a
  JUnit 5 unit test, a source-backup `Copy` task and a dependent `Zip` task
  were added; the Wrapper and JDK toolchain behaviour was documented with
  `./gradlew javaToolchains`; and the milestone `ca1-part1` was tagged.
- Part 2: the Bookstore was bootstrapped with `gradle init` and converted from
  Maven to Gradle with dependency and plugin management in
  `libs.versions.toml`, built and run with `bootRun`, and extended with the
  `deployToDev`, `runFromDistribution`, `javadocZip` and `integrationTest`
  tasks; the milestone `ca1-part2` was tagged.
- The alternative solution analysed Maven, Ant + Ivy, Bazel and Mill, compared
  them with Gradle, and implemented the Ant + Ivy design end to end.

Each feature was developed on a branch, tracked by a GitHub issue and
integrated through a pull request.

---

## 12. References

- Gradle user manual: <https://docs.gradle.org/9.4.0/userguide/userguide.html>
- Gradle Wrapper: <https://docs.gradle.org/9.4.0/userguide/gradle_wrapper.html>
- Gradle Java toolchains: <https://docs.gradle.org/9.4.0/userguide/toolchains.html>
- Gradle version catalogs: <https://docs.gradle.org/9.4.0/userguide/version_catalogs.html>
- Spring Boot Gradle plugin: <https://docs.spring.io/spring-boot/gradle-plugin/index.html>
- Spring Boot system requirements: <https://docs.spring.io/spring-boot/system-requirements.html>
- Apache Ant manual: <https://ant.apache.org/manual/>
- Apache Ant `junitlauncher` task: <https://ant.apache.org/manual/Tasks/junitlauncher.html>
- Apache Ivy: <https://ant.apache.org/ivy/>
- Apache Maven guides: <https://maven.apache.org/guides/index.html>
- Bazel documentation: <https://bazel.build/docs>
- Mill documentation: <https://mill-build.org/>
- Source application (Gradle demo and Bookstore):
  <https://github.com/lmpnogueira/cogsi/tree/main/build_tools>
