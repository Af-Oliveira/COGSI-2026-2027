# CA2 - Virtualization with Vagrant

Technical report for the second class assignment (CA2) of Configuracao e Gestao
de Sistemas (COGSI), Mestrado em Engenharia Informatica, Instituto Superior de
Engenharia do Porto.

- Topic: virtualization with Vagrant.
- Group repository: `Af-Oliveira/COGSI-2026-2027`.
- Milestone tags: `ca2-part1`, `ca2-part2`.
- Applications: the two CA1 projects - the Gradle demo chat application
  (`CA1/part1`) and the Bookstore Spring Boot application built with Gradle
  (`CA1/part2`).

This report follows a tutorial style: each requirement of the assignment is
quoted before the steps that implement it, the commands, the output they
produced and the explanation. Executing the instructions in order reproduces
the assignment.

---

## Table of contents

1. [Overview](#1-overview)
2. [Environment and prerequisites](#2-environment-and-prerequisites)
3. [Repository layout](#3-repository-layout)
4. [Operative guidelines](#4-operative-guidelines)
5. [Part 1 - First week](#5-part-1---first-week)
6. [References](#6-references)

---

## 1. Overview

Part 1 runs the two CA1 projects inside a single virtual machine created with
Vagrant. One `vagrant up` creates an Ubuntu 24.04 VM, installs the project
dependencies, clones the group repository, builds both applications and starts
them as services:

| Application | Runs in the VM as | Guest port | Used from the host with |
| --- | --- | --- | --- |
| Bookstore (Spring Boot) | `bookstore.service` | 8080 | browser or `curl` on `http://localhost:8080` |
| Chat server (Gradle demo) | `chat-server.service` | 59001 | the chat clients, `./gradlew runClient` |

The Bookstore stores its H2 database on disk, in a synced folder dedicated to
the database, so the data survives a restart and even the destruction of the
VM.

---

## 2. Environment and prerequisites

The work was performed with the tools below.

| Tool | Version | Purpose |
| --- | --- | --- |
| Host | Windows 11 Home, x86-64, 16 GB RAM | Runs the hypervisor and the chat clients. |
| VirtualBox | 7.2.20 | Provider: supplies the virtualization. |
| Vagrant | 2.4.9 | Creates, provisions and manages the VM. |
| Box | `bento/ubuntu-24.04` 202510.26.0 | Base image (Ubuntu 24.04.3 LTS, kernel 6.8.0-86). |
| Git / GitHub CLI | git 2.43 / gh 2.46 | Branches, tags, issues and pull requests. |

On Windows, VirtualBox and Vagrant can be installed with `winget`:

```bash
# install the provider and Vagrant
winget install --id Oracle.VirtualBox -e
winget install --id Hashicorp.Vagrant -e

# confirm the installed versions
vagrant --version
VBoxManage --version
```

```console
Vagrant 2.4.9
7.2.20r175154
```

> - `winget install --id ... -e` installs the package with that exact
>   identifier.
> - `vagrant --version` and `VBoxManage --version` print the installed
>   versions. `VBoxManage` is in `C:\Program Files\Oracle\VirtualBox`.
> - Vagrant is not a hypervisor: it drives a provider (VirtualBox here), which
>   is why both are required.

Two characteristics of the host influenced the results and are referenced in
the sections below.

- The host has WSL 2 enabled, so the Windows hypervisor (Hyper-V) is active
  and VirtualBox cannot use VT-x directly. It falls back to the Hyper-V API,
  which is slower. All the output in this report was captured with one virtual
  CPU (`VM_CPUS=1`) for the reason explained in
  [section 5.10](#510-problems-found-and-how-they-were-solved).
- The commands were issued from a WSL shell that calls the Windows
  `vagrant.exe`. Environment variables are only passed from WSL to a Windows
  process when they are listed in `WSLENV` (for example
  `WSLENV=VM_CPUS:START_SERVICES`). In PowerShell or in a native Linux or
  macOS shell this is not needed.

---

## 3. Repository layout

```text
COGSI-2026-2027/
├── README.md                 (repository root)
├── CA1/                      (the two applications used by this assignment)
│   ├── part1/                (Gradle demo chat application)
│   └── part2/                (Bookstore Spring Boot application, Gradle)
└── CA2/
    ├── README.md             (this technical report)
    ├── .gitignore            (.vagrant/ and the H2 database files)
    ├── .gitattributes        (LF line endings for files that run in the guest)
    └── part1/
        ├── Vagrantfile
        ├── provisioning/
        │   ├── base.sh       (project dependencies)
        │   ├── clone.sh      (clone or update the group repository)
        │   ├── build.sh      (build both applications)
        │   ├── deploy.sh     (artifacts, H2 configuration, systemd units)
        │   └── start.sh      (start the services, on every boot)
        └── h2-data/          (synced folder dedicated to the H2 database)
```

---

## 4. Operative guidelines

> Use your own group's private repository
> - Create a folder for each class assignment in the root of your repository,
>   where you should add the files specific to the assignment

The assignment lives in the `CA2/` folder, with one subfolder per part.

> Continue to operate Git via the command line
> - Create a branch for each feature and merge the completed feature into main

```bash
# create the feature branch for Part 1
git checkout -b feature/ca2-part1-vagrant
```

> - `git checkout -b` creates the branch and switches to it. Each component of
>   the assignment has its own branch (`feature/ca2-part1-vagrant`,
>   `feature/ca2-part2-multi-vm`, `feature/ca2-alternative-multipass`), merged
>   into `main` through a pull request.

> You will be using two different applications for this CA
> - Note: do not copy the .git folder from the app's original repository

The two applications are the ones already imported, without their original
history, into `CA1/part1` and `CA1/part2`. They are not copied again: the VM
obtains them by cloning the group repository.

> Create issue(s) in GitHub for your main tasks

The work is planned as a sprint. A milestone represents the sprint, labels
classify each issue, one epic groups the stories of each component, and the
user stories are attached to their epic as sub-issues.

```bash
# labels, by family (one example of each)
gh label create "sprint: CA2" --color 5319e7 --description "Sprint 2 - CA2 Virtualization with Vagrant"
gh label create "component: part1-single-vm" --color 0e8a16 --description "CA2 Part 1 - single VM running both applications"
gh label create "type: user story" --color 1d76db --description "Requirement written from the point of view of who benefits"
gh label create "area: provisioning" --color fbca04 --description "Shell provisioning scripts and idempotence"
gh label create "priority: must" --color b60205 --description "Required to meet the assignment requirements"

# the sprint
gh api repos/Af-Oliveira/COGSI-2026-2027/milestones \
  -f title="Sprint 2 - CA2 Virtualization with Vagrant" -f due_on="2026-10-18T23:59:59Z"

# one issue per epic, user story and task
gh issue create --title "Persist the H2 database in a dedicated synced folder" \
  --label "sprint: CA2,type: user story,component: part1-single-vm,area: persistence,priority: must" \
  --milestone "Sprint 2 - CA2 Virtualization with Vagrant" \
  --assignee Af-Oliveira,rmotafreitas --body-file story.md

# attach a story to its epic as a sub-issue
gh api -X POST repos/Af-Oliveira/COGSI-2026-2027/issues/10/sub_issues \
  -F sub_issue_id="$(gh api repos/Af-Oliveira/COGSI-2026-2027/issues/21 -q .id)"
```

| Label family | Values | Meaning |
| --- | --- | --- |
| `sprint:` | `CA1`, `CA2` | The assignment the issue belongs to. |
| `component:` | `part1-single-vm`, `part2-multi-vm`, `alternative`, `report` | The part of the sprint. |
| `type:` | `epic`, `user story`, `task`, `documentation`, `bug` | The kind of work. |
| `area:` | `vagrant`, `provisioning`, `networking`, `persistence`, `security`, `applications` | The technical area. |
| `priority:` | `must`, `should`, `could` | Required, expected for the higher grades, optional. |

| Epic | Issues |
| --- | --- |
| #10 Part 1 - Single VM running the CA1 applications | #14 to #23 |
| #11 Part 2 - Multi-VM environment (app, db and proxy) | #24 to #31 |
| #12 Alternative solution - managing VMs without Vagrant | #32 to #34 |
| #13 Technical report | #35 to #38 |

> - Every story states the user story, the assignment requirement it comes
>   from, its acceptance criteria, its tasks, how to verify it and the
>   definition of done.
> - `gh api .../sub_issues` links a story to its epic, so the progress of each
>   component is visible in the epic.

> Make several commits while you work (incremental, descriptive commit
> messages)

Each commit is one step of the work and references the issues it advances, so
the history can be followed from the issue to the code:

```bash
git log --oneline feature/ca2-part1-vagrant -5
```

```console
2736469 feat(ca2): start the services on every boot and expose them to the host
3645044 feat(ca2): deploy the applications with H2 persisted in a synced folder
2a5184a feat(ca2): clone the group repository and build both applications in the VM
606ce88 feat(ca2): create the Part 1 VM from a pinned box with base provisioning
4dafaa6 chore(ca2): scaffold the CA2 folder for the Vagrant assignment
```

> - The message body of each commit ends with `Refs #<issue>`, and the commit
>   that completes a story uses `Closes #<issue>`, which GitHub applies when
>   the branch is merged into `main`.

---

## 5. Part 1 - First week

> The goal of the Part 1 of this assignment is to practice with Vagrant using
> the same projects from CA1, but now inside a virtual machine

To reproduce Part 1, clone the repository on the host and bring the VM up:

```bash
git clone https://github.com/Af-Oliveira/COGSI-2026-2027.git
cd COGSI-2026-2027/CA2/part1
vagrant validate
vagrant up
```

```console
Vagrantfile validated successfully.
```

> - `vagrant validate` checks the Ruby syntax and the Vagrant settings of the
>   `Vagrantfile` without starting a VM.
> - `vagrant up` creates the VM and runs every provisioner. Its output is
>   shown step by step in the sections below. The output snippets are
>   abridged: separator lines, blank lines and repeated Gradle notices were
>   removed, and nothing else was changed.

### 5.1. Creating the VM from a pinned box

> You should start by creating a VM using Vagrant
> - Pin box version and justify box source trust

The VM is described in `CA2/part1/Vagrantfile`:

```ruby
Vagrant.require_version ">= 2.4.0", "< 3.0.0"

vm_memory = ENV["VM_MEMORY"] || "2048"
vm_cpus   = ENV["VM_CPUS"]   || "2"

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_version = "202510.26.0"
  config.vm.box_check_update = false

  config.vm.hostname = "cogsi-ca2-part1"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "cogsi-ca2-part1"
    vb.memory = vm_memory
    vb.cpus = vm_cpus
    vb.gui = false
  end

  config.vm.provider "vmware_desktop" do |vmware|
    vmware.vmx["memsize"] = vm_memory
    vmware.vmx["numvcpus"] = vm_cpus
  end
end
```

The first `vagrant up` downloads the box and creates the VM:

```console
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Box 'bento/ubuntu-24.04' could not be found. Attempting to find and install...
    default: Box Provider: virtualbox
    default: Box Version: 202510.26.0
==> default: Loading metadata for box 'bento/ubuntu-24.04'
    default: URL: https://vagrantcloud.com/api/v2/vagrant/bento/ubuntu-24.04
==> default: Adding box 'bento/ubuntu-24.04' (v202510.26.0) for provider: virtualbox (amd64)
    default: Downloading: https://vagrantcloud.com/bento/boxes/ubuntu-24.04/versions/202510.26.0/providers/virtualbox/amd64/vagrant.box
==> default: Successfully added box 'bento/ubuntu-24.04' (v202510.26.0) for 'virtualbox (amd64)'!
==> default: Importing base box 'bento/ubuntu-24.04'...
==> default: Setting the name of the VM: cogsi-ca2-part1
==> default: Preparing network interfaces based on configuration...
    default: Adapter 1: nat
    default: Adapter 2: hostonly
==> default: Forwarding ports...
    default: 8080 (guest) => 8080 (host) (adapter 1)
    default: 59001 (guest) => 59001 (host) (adapter 1)
    default: 22 (guest) => 2222 (host) (adapter 1)
==> default: Booting VM...
==> default: Waiting for machine to boot. This may take a few minutes...
    default: Vagrant insecure key detected. Vagrant will automatically replace
    default: this with a newly generated keypair for better security.
==> default: Machine booted and ready!
==> default: Setting hostname...
==> default: Configuring and enabling network interfaces...
==> default: Mounting shared folders...
    default: C:/Users/elisa/Documents/Afonso/COGSI-2026-2027/CA2/part1/h2-data => /h2-data
```

```bash
# the box that was installed and the state of the machine
vagrant box list
vagrant status

# the operating system, CPUs, memory and disk seen by the guest
vagrant ssh -c 'lsb_release -ds; uname -r; nproc; free -m | sed -n 1,2p; df -h / | tail -1'
```

```console
bento/ubuntu-24.04 (virtualbox, 202510.26.0, (amd64))

Current machine states:

default                   running (virtualbox)

Ubuntu 24.04.3 LTS
6.8.0-86-generic
1
               total        used        free      shared  buff/cache   available
Mem:            1968         599        1037           1         479        1368
/dev/mapper/ubuntu--vg-ubuntu--lv   31G  5.3G   24G  19% /
```

> - `Vagrant.require_version` refuses to run with a Vagrant version outside
>   the tested range, so a team member with an incompatible version gets a
>   clear error instead of a different environment.
> - `config.vm.box_version` pins the box. Without it, Vagrant would use the
>   newest version available when each person first runs `vagrant up`, and two
>   team members could end up with different images. `box_check_update = false`
>   also stops the outdated-box check on every `vagrant up`.
> - `vm_memory` and `vm_cpus` read host environment variables with a default,
>   so the resources can be adjusted to the host without editing the file. The
>   output above shows 1 CPU because it was captured with `VM_CPUS=1`.
> - The two provider blocks apply the same resources on VirtualBox and on
>   VMware Desktop, the provider used on Apple Silicon hosts.
> - `vagrant ssh -c '<command>'` runs a command in the guest and returns.

**Why the box is trusted.** The box comes from the Bento project, which is
maintained by Progress Chef. It is not an image prepared by an unknown user:

- The Packer templates that build every Bento box are public
  (<https://github.com/chef/bento>), so what is installed in the image can be
  inspected and the box can be rebuilt from source.
- The Vagrant documentation recommends the Bento boxes as the base boxes to
  use, and the lecture material uses the same box.
- The box is published for VirtualBox, VMware and Parallels, on `amd64` and
  `arm64`, so the same `Vagrantfile` works on the machines of both team
  members.
- It is a minimal Ubuntu LTS image; everything else is installed by the
  provisioning scripts in this repository, which are under version control.

One limitation was found: the metadata of this box in Vagrant Cloud does not
publish a checksum (`checksum_type` is `none`), so Vagrant cannot verify the
downloaded file against one. The integrity of the download relies on HTTPS
and on the identity of the publisher. A team that needed a stronger guarantee
would host the box itself, or record its own checksum and enforce it with
`config.vm.box_download_checksum`.

### 5.2. Installing the project dependencies

> Automate the installation of all the dependencies of the projects (e.g., Git,
> JDK, Maven, Gradle, etc.) using a provisioning shell script

> Ensure that the provisioning process is idempotent and can be safely executed
> more than once

The dependencies are installed by `provisioning/base.sh`, an external script
run by a named provisioner:

```ruby
config.vm.provision "shell",
  name: "base_packages",
  path: "provisioning/base.sh"
```

```bash
PACKAGES=(git curl openjdk-21-jdk-headless)

missing=()
for package in "${PACKAGES[@]}"; do
    if dpkg -s "$package" >/dev/null 2>&1; then
        echo "[OK] $package is already installed."
    else
        echo "[MISSING] $package"
        missing+=("$package")
    fi
done

if [ "${#missing[@]}" -gt 0 ]; then
    echo "[INSTALL] Installing: ${missing[*]}"
    apt-get update -qq
    apt-get install -y -qq -o Dpkg::Use-Pty=0 "${missing[@]}" >/dev/null
fi
```

Output of the first `vagrant up`:

```console
==> default: Running provisioner: base_packages (shell)...
    default: Installing project dependencies...
    default: [OK] git is already installed.
    default: [OK] curl is already installed.
    default: [MISSING] openjdk-21-jdk-headless
    default: [INSTALL] Installing: openjdk-21-jdk-headless
    default: [INFO] git version 2.43.0
    default: [INFO] openjdk version "21.0.12.1" 2026-08-18
    default: Project dependencies ready.
```

> - The script is external (`path:`) instead of inline, so it can be read,
>   reviewed and reused separately from the `Vagrantfile`. The `Vagrantfile`
>   describes the machine; the scripts describe its configuration.
> - `name:` gives the provisioner a name, which allows it to be executed on
>   its own with `vagrant provision --provision-with base_packages`.
> - `dpkg -s` checks whether each package is installed. Only the missing ones
>   are installed, and `apt-get update` runs only when something is missing,
>   which is what makes the script idempotent and fast on later runs.
> - `openjdk-21-jdk-headless` is JDK 21, the toolchain declared by both builds
>   (`JavaLanguageVersion.of(21)`). Gradle finds it in `/usr/lib/jvm`, so no
>   JDK is downloaded during the build. The headless variant is enough because
>   the VM has no display.

**Gradle and Maven are deliberately not installed.**

- Both projects include the Gradle Wrapper, which downloads the exact Gradle
  version they were written for (9.4.0). The version packaged by Ubuntu 24.04
  is 4.4.1 (`apt-cache policy gradle` reports `Candidate: 4.4.1-20`), which
  cannot run these builds.
- Maven is not needed: the Bookstore in the group repository is the Gradle
  conversion made in CA1, not the original Maven project.

### 5.3. Cloning the group repository

> Clone your group's repository inside the VM

`provisioning/clone.sh` runs as the `vagrant` user and receives its settings
through the `env:` block:

```ruby
config.vm.provision "shell",
  name: "clone_repository",
  path: "provisioning/clone.sh",
  privileged: false,
  env: {
    "CLONE_REPO"   => clone_repo,
    "REPO_URL"     => repo_url,
    "REPO_BRANCH"  => repo_branch,
    "REPO_DIR"     => repo_dir,
    "GITHUB_TOKEN" => github_token
  }
```

```bash
git_auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    credentials=$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 -w0)
    git_auth=(-c "http.extraHeader=Authorization: Basic $credentials")
fi

if [ -d "$REPO_DIR/.git" ]; then
    echo "[OK] Repository already cloned in $REPO_DIR - updating $REPO_BRANCH."
    git "${git_auth[@]}" -C "$REPO_DIR" fetch --quiet --prune origin
    git -C "$REPO_DIR" checkout --quiet "$REPO_BRANCH"
    git -C "$REPO_DIR" merge --quiet --ff-only "origin/$REPO_BRANCH"
else
    echo "[CLONE] Cloning $REPO_URL ($REPO_BRANCH) into $REPO_DIR"
    git "${git_auth[@]}" clone --quiet --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi
```

```console
==> default: Running provisioner: clone_repository (shell)...
    default: [CLONE] Cloning https://github.com/Af-Oliveira/COGSI-2026-2027.git (main) into /home/vagrant/COGSI-2026-2027
    default: [INFO] HEAD is now at 15c107d Merge pull request #9 from Af-Oliveira/docs/ca1-report
```

```bash
# the working copy inside the VM and its owner
vagrant ssh -c 'ls ~/COGSI-2026-2027; ls -ld ~/COGSI-2026-2027 | cut -d" " -f1,3,4'
```

```console
CA1
README.md
drwxrwxr-x vagrant vagrant
```

> - `privileged: false` runs the script as `vagrant` instead of `root`, so the
>   working copy and the build output belong to the user that builds them.
> - When the working copy already exists the script fetches and fast-forwards
>   it instead of cloning again, which makes the step repeatable.
> - `REPO_URL` and `REPO_BRANCH` default to the group repository and `main`,
>   and can be changed from the host.
> - `GITHUB_TOKEN` is optional and only needed if the repository is private.
>   The token is sent as an HTTP header for that Git invocation
>   (`-c http.extraHeader=...`). It is not part of the URL, so it is not saved
>   in `.git/config`, and it is never written to the `Vagrantfile`.
> - The applications are obtained from the clone and not from a synced folder,
>   as required. Building on the VM disk is also faster and more reliable than
>   building on a VirtualBox shared folder.

### 5.4. Building the applications

> Build and execute the Bookstore Spring Boot application and the Gradle demo
> application (from the previous assignment)

`provisioning/build.sh` builds each project with its own Gradle Wrapper:

```bash
run_gradle() {
    local project=$1
    shift
    echo "[BUILD] $project: ./gradlew $*"
    (cd "$REPO_DIR/$project" && ./gradlew --no-daemon --console=plain "$@")
}

run_gradle CA1/part2 bootJar
run_gradle CA1/part1 packageApp
```

```console
==> default: Running provisioner: build_apps (shell)...
    default: [BUILD] CA1/part2: ./gradlew bootJar
    default: Downloading https://services.gradle.org/distributions/gradle-9.4.0-bin.zip
    default: Welcome to Gradle 9.4.0!
    default: > Task :processResources
    default: > Task :compileJava
    default: > Task :classes
    default: > Task :resolveMainClassName
    default: > Task :bootJar
    default:
    default: BUILD SUCCESSFUL in 9m 17s
    default: 4 actionable tasks: 4 executed
    default: [BUILD] CA1/part1: ./gradlew packageApp
    default: > Task :app:copyDependencies
    default: > Task :app:compileJava
    default: > Task :app:processResources
    default: > Task :app:classes
    default: > Task :app:jar
    default: Generated application JAR: chat-server-1.0.jar
    default: > Task :app:packageApp
    default:
    default: BUILD SUCCESSFUL in 2m 52s
    default: 4 actionable tasks: 4 executed
    default: [INFO] Build finished.
```

> - `bootJar` produces the executable Spring Boot jar of the Bookstore.
> - `packageApp` is the CA1 task that builds the chat jar and copies its
>   runtime dependencies (Log4j) next to it.
> - `--no-daemon` avoids leaving a Gradle daemon resident in a VM with 2 GB of
>   memory, and `--console=plain` produces output that is readable in the
>   Vagrant log.
> - The first build is slow on this host because Gradle and every dependency
>   are downloaded and because of the Hyper-V fallback described in section 2.
>   Later builds reuse the caches (section 5.9).

`provisioning/deploy.sh` then installs the artifacts outside the working copy
and describes how each application runs:

```console
==> default: Running provisioner: deploy_apps (shell)...
    default: Deploying the applications...
    default: [DEPLOY] /opt/bookstore/bookstore.jar
    default: [DEPLOY] /etc/bookstore/application.properties
    default: [DEPLOY] /etc/systemd/system/bookstore.service
    default: [DEPLOY] /opt/chat-server/chat-server.jar
    default: [DEPLOY] /opt/chat-server/lib
    default: [DEPLOY] /etc/systemd/system/chat-server.service
    default: Deployment complete.
```

```bash
vagrant ssh -c 'ls -l /opt/bookstore /opt/chat-server /opt/chat-server/lib'
```

```console
/opt/bookstore:
total 54500
-rw-r--r-- 1 root root 55806170 Oct  9 19:06 bookstore.jar

/opt/chat-server:
total 16
-rw-r--r-- 1 root root 9595 Oct  9 19:06 chat-server.jar
drwxr-xr-x 2 root root 4096 Oct  9 19:06 lib

/opt/chat-server/lib:
total 2316
-rw-r--r-- 1 root root  351428 Oct  9 19:06 log4j-api-2.26.1.jar
-rw-r--r-- 1 root root 2015459 Oct  9 19:06 log4j-core-2.26.1.jar
```

> - The artifacts are copied to `/opt` so that the running applications do not
>   depend on the build tree, which can be rebuilt or cleaned at any time.
> - Each application is described by a systemd unit, so it runs under the
>   unprivileged `vagrant` user, is restarted if it fails, and writes its
>   output to the journal (`journalctl -u bookstore`).

### 5.5. Using the Bookstore from the host browser

> Interact with both applications from your host machine
> - For the Bookstore Spring Boot application, you should access the web
>   interface from the browser in your host machine

By default the VM is behind NAT and is not reachable from the host. The
`Vagrantfile` exposes the application in two ways:

```ruby
config.vm.network "forwarded_port",
  guest: bookstore_port, host: bookstore_host_port,
  host_ip: "127.0.0.1", auto_correct: true

config.vm.network "private_network", ip: vm_ip
```

`provisioning/start.sh` starts the service and waits until it answers:

```console
==> default: Running provisioner: start_services (shell)...
    default: Starting the services...
    default: [START] bookstore
    default: [READY] Bookstore on port 8080 (after 91s)
    default: [START] chat-server
    default: [READY] Chat server on port 59001 (after 1s)
    default: Services started.
```

On the host, open <http://localhost:8080/books> in the browser, or use `curl`:

```bash
# the forwarded ports of the machine
vagrant port

# the API entry point and the list of books, from the host
curl -s http://localhost:8080/
curl -s http://localhost:8080/books
curl -s http://localhost:8080/actuator/health

# the same application through the private network address
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.56.10:8080/books
```

```console
 59001 (guest) => 59001 (host)
  8080 (guest) => 8080 (host)
    22 (guest) => 2222 (host)

{"_links":{"books":{"href":"http://localhost:8080/books"},"clients":{"href":"http://localhost:8080/clients"},"orders":{"href":"http://localhost:8080/orders"},"health":{"href":"http://localhost:8080/health"},"info":{"href":"http://localhost:8080/info"}}}
[{"author":"Robert C. Martin","id":1,"price":30.0,"title":"Clean Code"},{"author":"Joshua Bloch","id":2,"price":40.0,"title":"Effective Java"}]
{"groups":["liveness","readiness"],"status":"UP"}
200
```

```bash
# the service and the listening sockets inside the VM
vagrant ssh -c 'systemctl status bookstore --no-pager | sed -n 1,9p; ss -ltnH | grep -E ":(8080|59001) "; ip -4 -br addr'
```

```console
● bookstore.service - Bookstore Spring Boot application (COGSI)
     Loaded: loaded (/etc/systemd/system/bookstore.service; disabled; preset: enabled)
     Active: active (running) since Fri 2026-10-09 19:24:55 UTC; 11min ago
   Main PID: 2167 (java)
      Tasks: 33 (limit: 2264)
     Memory: 234.5M (peak: 234.7M)
        CPU: 1min 38.989s
     CGroup: /system.slice/bookstore.service
             └─2167 /usr/bin/java -jar /opt/bookstore/bookstore.jar --spring.config.additional-location=file:/etc/bookstore/
LISTEN 0      50                 *:59001       *:*
LISTEN 0      100                *:8080        *:*
lo               UNKNOWN        127.0.0.1/8
eth0             UP             10.0.2.15/24 metric 100
eth1             UP             192.168.56.10/24
```

> - **How `localhost:8080` reaches the guest.** `eth0` is the NAT adapter
>   (`10.0.2.15`), which the host cannot address. The `forwarded_port` rule
>   makes VirtualBox listen on port 8080 of the host and relay each connection
>   through the NAT adapter to port 8080 of the guest, where Spring Boot
>   listens on all interfaces (`*:8080`).
> - `host_ip: "127.0.0.1"` binds the forwarded port to the loopback interface
>   of the host. Without it the port would be open on every interface of the
>   host, and therefore to the whole local network.
> - `auto_correct: true` lets Vagrant choose another host port if 8080 is
>   already in use; `vagrant port` shows the ports actually assigned. The host
>   port can also be chosen with `BOOKSTORE_HOST_PORT`.
> - `private_network` adds a second adapter (`eth1`) with the static address
>   `192.168.56.10` on the VirtualBox host-only network, where the host is
>   `192.168.56.1`. It is an alternative to the forwarded port that does not
>   depend on a free host port. The address can be changed with `VM_IP`.
> - The wait in `start.sh` polls `/actuator/health` once per second, so the
>   provisioning only finishes when the application is really answering, and
>   fails with the service log if it does not start within 180 seconds.

### 5.6. Chat server in the VM, clients on the host

> For the simple chat application, you should execute the server inside the VM
> and the clients in your host machine

The server is the `chat-server.service` started in the previous section. Its
port is forwarded in the same way as the Bookstore port:

```ruby
config.vm.network "forwarded_port",
  guest: chat_port, host: chat_host_port,
  host_ip: "127.0.0.1", auto_correct: true
```

The clients are started on the host, from the host copy of the repository,
each in its own terminal:

```bash
cd COGSI-2026-2027/CA1/part1
./gradlew runClient -PserverIP=localhost -PserverPort=59001
```

Each client opens a window that asks for a screen name and then shows the
conversation. The server log in the VM records the clients joining and
leaving:

```bash
vagrant ssh -c 'journalctl -u chat-server --no-pager -o cat -n 5'
```

```console
The chat server is running...
19:34:10.803 [pool-1-thread-1] INFO  org.example.ChatServer.Handler - A new user has joined: afonso
19:34:10.873 [pool-1-thread-2] INFO  org.example.ChatServer.Handler - A new user has joined: ricardo
19:34:10.931 [pool-1-thread-1] INFO  org.example.ChatServer.Handler - afonso has left the chat
19:34:10.929 [pool-1-thread-2] INFO  org.example.ChatServer.Handler - ricardo has left the chat
```

The log above was produced by a scripted check that opens two connections
from the host to `127.0.0.1:59001` and speaks the protocol of the application
directly, which shows the complete path from the host to the server in the VM:

```console
[afonso] <- SUBMITNAME
[afonso] <- NAMEACCEPTED afonso
[ricardo] <- SUBMITNAME
[ricardo] <- NAMEACCEPTED ricardo
[afonso] <- MESSAGE ricardo has joined
[afonso] <- MESSAGE afonso: hello from the host
[ricardo] <- MESSAGE afonso: hello from the host
```

> - `runClient` is the CA1 task that starts `ChatClientApp` with the server
>   address and port given as Gradle properties. `localhost:59001` on the host
>   is the forwarded port; `-PserverIP=192.168.56.10` reaches the same server
>   through the private network.
> - The server sends `SUBMITNAME`, accepts the name with `NAMEACCEPTED` and
>   broadcasts every line as `MESSAGE <name>: <text>` to all the clients.
> - The server is started from its jar
>   (`java -cp /opt/chat-server/chat-server.jar:/opt/chat-server/lib/* org.example.ChatServerApp 59001`)
>   instead of `./gradlew runServer`, so that the service does not keep a
>   Gradle process running around it.

> Note: some goals of the Gradle demo project may not execute in the VM because
> it does not have a GUI
> - You should report and explain possible issues you may encounter in your
>   readme file!

The chat client is a Swing application. Running it inside the VM fails:

```bash
vagrant ssh -c 'cd ~/COGSI-2026-2027/CA1/part1 && ./gradlew --no-daemon --console=plain runClient -PserverIP=localhost -PserverPort=59001'
```

```console
> Task :app:runClient
Starting ChatClientApp with server IP: localhost and port: 59001
Exception in thread "main" java.awt.HeadlessException:
No X11 DISPLAY variable was set,
or no headful library support was found,
but this program performed an operation which requires it.
	at java.desktop/java.awt.GraphicsEnvironment.checkHeadless(GraphicsEnvironment.java:164)
	at java.desktop/java.awt.Window.<init>(Window.java:553)
	at java.desktop/java.awt.Frame.<init>(Frame.java:428)
	at java.desktop/javax.swing.JFrame.<init>(JFrame.java:224)
	at org.example.ChatClient.<init>(ChatClient.java:36)
	at org.example.ChatClientApp.main(ChatClientApp.java:29)

> Task :app:runClient FAILED

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:runClient'.
> Process 'command '/usr/lib/jvm/java-21-openjdk-amd64/bin/java'' finished with non-zero exit value 1

BUILD FAILED in 1m 22s
```

| Goal | In the VM | Explanation |
| --- | --- | --- |
| `build`, `test`, `jar`, `packageApp`, `backupSources`, `backupZip` | Works | They only compile, test and copy files. Compiling the client does not need a display, and the two unit tests pass. |
| `ChatServerApp`, the class behind `runServer`, run as `chat-server.service` | Works | The server only uses sockets and the console logger. |
| `runClient` | Fails with `HeadlessException` | `ChatClient` creates a `JFrame` in its constructor. The VM has no X11 display (`DISPLAY` is empty) and the installed JDK is the headless variant, which does not include the native windowing libraries. |

> - The failure is not a build problem: the task compiles and starts, and it
>   is the client process that stops when it tries to create a window.
> - This is the reason for the split asked by the assignment: the component
>   with a graphical interface stays on the host, where there is a display,
>   and the component without one runs in the VM.
> - Running the client in the VM would require a desktop environment in the
>   guest (`vb.gui = true`) or X11 forwarding to an X server on the host
>   (`config.ssh.forward_x11 = true`) together with the non-headless JDK.
>   Neither is useful here.

### 5.7. Controlling the steps with environment variables

> Automate the cloning, building, and starting of applications
> - Use environment variables to control whether specific steps (like repo
>   cloning or service start-up) should be executed when provisioning

The `Vagrantfile` reads the host environment with a default for each variable
and passes the values to the scripts through `env:`:

```ruby
clone_repo     = ENV["CLONE_REPO"]     || "true"
build_apps     = ENV["BUILD_APPS"]     || "true"
start_services = ENV["START_SERVICES"] || "true"
```

```bash
# provisioning/clone.sh - the same guard exists in build.sh and start.sh
if [ "$CLONE_REPO" != "true" ]; then
    echo "[SKIP] CLONE_REPO=$CLONE_REPO - the repository was not cloned or updated."
    exit 0
fi
```

| Variable | Default | Effect |
| --- | --- | --- |
| `CLONE_REPO` | `true` | Clone or update the group repository. |
| `BUILD_APPS` | `true` | Build the two applications. |
| `START_SERVICES` | `true` | Start the two services and wait for them. |
| `REPO_URL` | the group repository | Repository to clone. |
| `REPO_BRANCH` | `main` | Branch to check out. |
| `GITHUB_TOKEN` | empty | Access token, only for a private repository. |
| `VM_MEMORY` | `2048` | Memory of the VM, in MB. |
| `VM_CPUS` | `2` | Virtual CPUs of the VM. |
| `VM_IP` | `192.168.56.10` | Address on the private network. |
| `BOOKSTORE_HOST_PORT` | `8080` | Host port forwarded to the Bookstore. |
| `CHAT_HOST_PORT` | `59001` | Host port forwarded to the chat server. |

```bash
# Bash: provision without cloning, building or starting anything
CLONE_REPO=false BUILD_APPS=false START_SERVICES=false vagrant provision

# PowerShell equivalent
$env:CLONE_REPO = "false"; $env:BUILD_APPS = "false"; $env:START_SERVICES = "false"
vagrant provision
```

```console
==> default: Running provisioner: clone_repository (shell)...
    default: [SKIP] CLONE_REPO=false - the repository was not cloned or updated.
==> default: Running provisioner: build_apps (shell)...
    default: [SKIP] BUILD_APPS=false - the applications were not built.
==> default: Running provisioner: deploy_apps (shell)...
    default: Deploying the applications...
    default: [OK] /opt/bookstore/bookstore.jar is up to date.
    default: [OK] /etc/bookstore/application.properties is up to date.
    default: [OK] /etc/systemd/system/bookstore.service is up to date.
    default: [OK] /opt/chat-server/chat-server.jar is up to date.
    default: [OK] /opt/chat-server/lib is up to date.
    default: [OK] /etc/systemd/system/chat-server.service is up to date.
    default: Deployment complete.
==> default: Running provisioner: start_services (shell)...
    default: [SKIP] START_SERVICES=false - the services were not started.
```

> - `ENV["NAME"] || "default"` reads a host variable and falls back to the
>   default when it is not set, so `vagrant up` works with no configuration.
> - The decision is taken inside each script, which logs `[SKIP]` and exits
>   with success. The log therefore shows explicitly which steps did not run.
> - `env:` makes the values available to the script as ordinary environment
>   variables, keeping the logic in the script and the values in the
>   `Vagrantfile`.
> - No secret is written in the `Vagrantfile`: the only sensitive value,
>   `GITHUB_TOKEN`, exists only in the environment of the host.
> - The variables combine with the named provisioners. For example,
>   `vagrant provision --provision-with build_apps,deploy_apps,start_services`
>   rebuilds and redeploys without touching the packages or the clone.

### 5.8. Persisting the H2 database

> Ensure the H2 database in the VM retains data across restarts
> - In the VM's provisioning script, configure the H2 database to store data on
>   disk, using a synced folder between the VM and the host machine for
>   persistent storage
> - You must create or modify the application.properties configuration file to
>   specify the correct database URL
> - Use a synced folder dedicated to persistent DB storage, not the default
>   project folder
> - Verify that data survives a VM restart or reload

The `Vagrantfile` disables the default project share and declares a folder
used only by the database:

```ruby
config.vm.synced_folder ".", "/vagrant", disabled: true
config.vm.synced_folder "./h2-data", h2_data_dir   # h2_data_dir = "/h2-data"
```

`provisioning/deploy.sh` creates an `application.properties` outside the jar
and starts the Bookstore with it:

```properties
# /etc/bookstore/application.properties
spring.datasource.url=jdbc:h2:file:/h2-data/bookstore;DB_CLOSE_ON_EXIT=FALSE
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=
spring.jpa.hibernate.ddl-auto=update
server.port=8080
spring.jpa.show-sql=false
```

```ini
# /etc/systemd/system/bookstore.service (excerpt)
[Unit]
AssertPathIsMountPoint=/h2-data

[Service]
User=vagrant
ExecStart=/usr/bin/java -jar /opt/bookstore/bookstore.jar --spring.config.additional-location=file:/etc/bookstore/
```

> - The application packaged in CA1 uses `jdbc:h2:mem:bookstore`, a database
>   that exists only in the memory of the process. `jdbc:h2:file:` makes H2
>   store the database in the file `/h2-data/bookstore.mv.db`.
> - `spring.config.additional-location` makes Spring Boot load this file after
>   the `application.properties` inside the jar, so its values override the
>   packaged ones. The CA1 sources keep their in-memory default and only this
>   VM uses a file database.
> - `ddl-auto=update` keeps the existing tables and rows instead of recreating
>   the schema on each start.
> - `./h2-data` is a folder of the host shared with the guest as `/h2-data`.
>   It is dedicated to the database: the default `/vagrant` share of the
>   project folder is disabled. The host folder must exist before
>   `vagrant up`, which is why the repository tracks `h2-data/.gitkeep`; the
>   database files themselves are ignored by Git.
> - `AssertPathIsMountPoint` makes the service refuse to start if the shared
>   folder is not mounted. Without it, H2 would silently create a new, empty
>   database in the `/h2-data` directory of the VM disk.

**Verification.** A book is created through the API, the VM is restarted, and
the book is still there:

```bash
# create a book from the host
curl -s -X POST http://localhost:8080/books -H "Content-Type: application/json" \
  -d '{"title":"Persistence test","author":"CA2","price":1}'

# restart the VM and list the books again
vagrant reload
curl -s http://localhost:8080/books

# the database file, seen from the host
ls -l h2-data
```

```console
{"author":"CA2","id":3,"price":1.0,"title":"Persistence test"}

==> default: Machine already provisioned. Run `vagrant provision` or use the `--provision`
==> default: flag to force provisioning. Provisioners marked to run always will still run.
==> default: Running provisioner: start_services (shell)...
    default: [START] bookstore
    default: [READY] Bookstore on port 8080 (after 108s)
    default: [START] chat-server
    default: [READY] Chat server on port 59001 (after 2s)

[{"author":"Robert C. Martin","id":1,"price":30.0,"title":"Clean Code"},{"author":"Joshua Bloch","id":2,"price":40.0,"title":"Effective Java"},{"author":"CA2","id":3,"price":1.0,"title":"Persistence test"},{"author":"Robert C. Martin","id":52,"price":30.0,"title":"Clean Code"},{"author":"Joshua Bloch","id":53,"price":40.0,"title":"Effective Java"}]

-rwxrwxrwx 1 elisa elisa 40960 Oct  9 20:19 bookstore.mv.db
```

The same book was still returned after `vagrant destroy -f` followed by
`vagrant up`, which creates a completely new VM: the database is on the host,
outside the VM disk.

The guard of the service was also tested, by unmounting the folder in the
guest and trying to start the Bookstore:

```console
Assertion failed on job for bookstore.service.
systemctl start exit code: 1
bookstore.service: Starting requested but asserts failed.
```

> - `vagrant reload` halts the VM and boots it again. Only the `start_services`
>   provisioner runs, because it is declared with `run: "always"`.
> - The book with `id` 3 survives the restart, which shows that the data is
>   read from the file in the synced folder.
> - **The sample data is duplicated on each start.** The books with `id` 52
>   and 53 are new copies of the two sample books. The `DataInitializer` of
>   the application inserts the sample data every time it starts, without
>   checking whether it already exists. With the in-memory database this was
>   invisible, because the database was empty on every start. This is the
>   behaviour of the application and not of the provisioning; it was left
>   unchanged because the assignment is about the environment, and it is in
>   fact additional evidence that the earlier rows are kept. The fix would be
>   to insert the sample data only when the tables are empty.

**Why the services are started by a provisioner.** The units are installed but
not enabled at boot. The `start_services` provisioner runs on every
`vagrant up` and `vagrant reload`, after Vagrant has mounted the synced
folder, which guarantees that the database is available when the Bookstore
starts and keeps the start-up under the control of `START_SERVICES`.

### 5.9. Idempotent provisioning

> Ensure that the provisioning process is idempotent and can be safely executed
> more than once

Running the provisioning again on a machine that is already provisioned
changes nothing:

```bash
vagrant provision
```

```console
==> default: Running provisioner: base_packages (shell)...
    default: [OK] git is already installed.
    default: [OK] curl is already installed.
    default: [OK] openjdk-21-jdk-headless is already installed.
==> default: Running provisioner: clone_repository (shell)...
    default: [OK] Repository already cloned in /home/vagrant/COGSI-2026-2027 - updating main.
    default: [INFO] HEAD is now at 15c107d Merge pull request #9 from Af-Oliveira/docs/ca1-report
==> default: Running provisioner: build_apps (shell)...
    default: [BUILD] CA1/part2: ./gradlew bootJar
    default: Reusing configuration cache.
    default: > Task :compileJava UP-TO-DATE
    default: > Task :processResources UP-TO-DATE
    default: > Task :classes UP-TO-DATE
    default: > Task :resolveMainClassName UP-TO-DATE
    default: > Task :bootJar UP-TO-DATE
    default: BUILD SUCCESSFUL in 1m 20s
    default: 4 actionable tasks: 4 up-to-date
    default: [BUILD] CA1/part1: ./gradlew packageApp
    default: Reusing configuration cache.
    default: > Task :app:copyDependencies UP-TO-DATE
    default: > Task :app:compileJava UP-TO-DATE
    default: > Task :app:processResources UP-TO-DATE
    default: > Task :app:classes UP-TO-DATE
    default: > Task :app:jar UP-TO-DATE
    default: > Task :app:packageApp UP-TO-DATE
    default: BUILD SUCCESSFUL in 1m 18s
    default: 4 actionable tasks: 4 up-to-date
==> default: Running provisioner: deploy_apps (shell)...
    default: [OK] /opt/bookstore/bookstore.jar is up to date.
    default: [OK] /etc/bookstore/application.properties is up to date.
    default: [OK] /etc/systemd/system/bookstore.service is up to date.
    default: [OK] /opt/chat-server/chat-server.jar is up to date.
    default: [OK] /opt/chat-server/lib is up to date.
    default: [OK] /etc/systemd/system/chat-server.service is up to date.
==> default: Running provisioner: start_services (shell)...
    default: [OK] bookstore is already running.
    default: [READY] Bookstore on port 8080 (after 0s)
    default: [OK] chat-server is already running.
    default: [READY] Chat server on port 59001 (after 0s)
```

A shell script is imperative, so idempotence has to be written explicitly.
Each script checks the current state before changing it:

| Script | Technique |
| --- | --- |
| `base.sh` | `dpkg -s` for each package; `apt-get` runs only for the missing ones. |
| `clone.sh` | Clones only if `.git` does not exist; otherwise fetches and fast-forwards. |
| `build.sh` | Relies on Gradle, which skips every task whose inputs did not change (`UP-TO-DATE`). |
| `deploy.sh` | Compares each file with `cmp` and copies it only when the content differs. A change leaves a marker in `/run/cogsi-restart/`. |
| `start.sh` | Starts a stopped service, restarts a running one only if its marker exists, and otherwise leaves it running. |

The markers make a change propagate to the right service only. When the
generated `application.properties` was changed during development, the next
`vagrant provision` reported exactly that:

```console
    default: [OK] /opt/bookstore/bookstore.jar is up to date.
    default: [DEPLOY] /etc/bookstore/application.properties
    default: [OK] /etc/systemd/system/bookstore.service is up to date.
    ...
    default: [RESTART] bookstore - its deployment changed.
    default: [READY] Bookstore on port 8080 (after 81s)
    default: [OK] chat-server is already running.
```

> - Idempotence is what makes it safe to repeat `vagrant provision` after an
>   interrupted run or after editing a script: the result is the same final
>   state, and the work that is already done is not repeated.
> - Restarting only what changed matters for the Bookstore, which takes more
>   than a minute to start on this host.
> - The complete cycle was also verified from a clean state with
>   `vagrant destroy -f` followed by `vagrant up`, which ended with both
>   applications running (24 minutes on this host, most of it in the first
>   Gradle build).

### 5.10. Problems found and how they were solved

**The VM froze with two virtual CPUs.** During the first `vagrant up`, with
the default of two CPUs, the guest stopped responding in the middle of the
second Gradle build and Vagrant ended with:

```console
The SSH connection was unexpectedly closed by the remote end. This
usually indicates that SSH within the guest machine was unable to
properly start up. Please boot the VM in GUI mode to check whether
it is booting properly.
```

Following the troubleshooting workflow from the lectures, the failing layer
was identified as the provider, not the provisioning. The VirtualBox log of
the VM (`VirtualBox VMs/cogsi-ca2-part1/Logs/VBox.log`) showed that
hardware virtualization was being provided by Hyper-V and that the guest had
stopped answering:

```console
HM: HMR3Init: Attempting fall back to NEM: VT-x is not available
NEM: WHvCapabilityCodeHypervisorPresent is TRUE, so this might work...
VMMDev: vmmDevHeartbeatFlatlinedTimer: Guest seems to be unresponsive. Last heartbeat received 4 seconds ago
TM: Giving up catch-up attempt at a 61 196 867 306 ns lag; new total: 61 196 867 306 ns
```

```bash
# power off the frozen VM and bring it up again with one CPU
vagrant halt -f
VM_CPUS=1 vagrant up --provision
```

> - The host has WSL 2 enabled, so Hyper-V owns VT-x and VirtualBox runs the
>   guest through the Windows Hypervisor Platform (`NEM`). In this mode a
>   guest with two CPUs under load became unresponsive; with one CPU every
>   later run completed, including the clean `destroy` and `up` cycle.
> - The fix did not require editing the `Vagrantfile`: `VM_CPUS` exists for
>   this kind of host-specific adjustment. The default remains 2, which is the
>   appropriate value for a host where VirtualBox uses VT-x directly.
> - The second run resumed where the first had stopped. The packages and the
>   clone were reported as `[OK]` and only the builds were executed again,
>   which is a practical demonstration of the idempotent provisioning.
> - The alternative is to disable Hyper-V on the host, which would also
>   disable WSL 2, so it was not done.

**The H2 console is not available.** The original Bookstore documents an H2
console at `/h2-console`, and `spring.h2.console.enabled=true` is still in
its `application.properties`. Requested from the host or from inside the VM,
that address answers 404. In Spring Boot 4 the console is provided by a separate module
that the CA1 build does not include, so the property has no effect:

```bash
vagrant ssh -c 'curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/h2-console; jar tf /opt/bookstore/bookstore.jar | grep -i -E "lib/(h2|spring-boot-h2)"'
```

```console
404
BOOT-INF/lib/h2-2.4.240.jar
```

> - The jar contains the H2 engine but no `spring-boot-h2console` module. The
>   database is inspected through the REST API instead. This is unrelated to
>   the VM and was not changed.

**The other issues** are described where they occur: the chat client cannot
run in the VM because there is no display (section 5.6), the sample data is
duplicated on every start once the database is persistent (section 5.8), and
the box metadata publishes no checksum (section 5.1).

### 5.11. Files committed and the Part 1 tag

> Only commit the files necessary to reproduce the assignment (in a folder for
> Part 1 of CA2)
> - e.g., README.md, Vagrantfile, provisioning scripts, configuration files,
>   and supporting assets

```bash
git ls-files CA2
```

```console
CA2/.gitattributes
CA2/.gitignore
CA2/README.md
CA2/part1/Vagrantfile
CA2/part1/h2-data/.gitkeep
CA2/part1/provisioning/base.sh
CA2/part1/provisioning/build.sh
CA2/part1/provisioning/clone.sh
CA2/part1/provisioning/deploy.sh
CA2/part1/provisioning/start.sh
```

> - `CA2/.gitignore` excludes `.vagrant/`, which holds the machine ID and the
>   SSH key generated for this VM and is specific to each computer, and the H2
>   database files written to `part1/h2-data/`.
> - `CA2/.gitattributes` forces LF line endings on the scripts and on the
>   `Vagrantfile`. The repository is used on Windows, where Git may convert
>   text files to CRLF, and a script with CRLF fails in the guest with
>   `/bin/bash^M: bad interpreter`.
> - The applications are not copied into `CA2/`: they are cloned by the VM.

---

## 6. References

- Vagrant documentation: <https://developer.hashicorp.com/vagrant/docs>
- Vagrant shell provisioner: <https://developer.hashicorp.com/vagrant/docs/provisioning/shell>
- Vagrant synced folders: <https://developer.hashicorp.com/vagrant/docs/synced-folders>
- Vagrant networking: <https://developer.hashicorp.com/vagrant/docs/networking>
- Vagrant boxes and box versioning: <https://developer.hashicorp.com/vagrant/docs/boxes>
- Bento project: <https://github.com/chef/bento>
- Bento Ubuntu 24.04 box: <https://portal.cloud.hashicorp.com/vagrant/discover/bento/ubuntu-24.04>
- VirtualBox user manual: <https://www.virtualbox.org/manual/>
- H2 database features (connection modes and URLs): <https://www.h2database.com/html/features.html>
- Spring Boot externalized configuration: <https://docs.spring.io/spring-boot/reference/features/external-config.html>
- systemd unit configuration: <https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html>
- Lecture example repository (virtualization module):
  <https://github.com/lmpnogueira/cogsi/tree/main/virtualization>
