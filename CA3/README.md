# CA3 - Configuration Management with Ansible

Technical report for the third class assignment (CA3) of Configuracao e Gestao
de Sistemas (COGSI), Mestrado em Engenharia Informatica, Instituto Superior de
Engenharia do Porto.

- Topic: provisioning with Ansible.
- Group repository: `Af-Oliveira/COGSI-2026-2027`.
- Milestone tag: `ca3`.
- Application: the Gradle version of the Bookstore Spring Boot application
  (`CA1/part2`), deployed on the three-machine environment of CA2 Part 2.

This report follows a tutorial style: each requirement of the assignment is
quoted before the steps that implement it, the commands, the output they
produced and the explanation. Executing the instructions in order reproduces
the assignment.

---

## Table of contents

1. [Overview](#1-overview)
2. [Environment and prerequisites](#2-environment-and-prerequisites)
3. [Repository layout](#3-repository-layout)
4. [Ansible provisioning](#4-ansible-provisioning)

---

## 1. Overview

CA2 Part 2 built a three-tier environment with Vagrant and configured each
machine with shell scripts:

| Machine | Private address | Role |
| --- | --- | --- |
| `db` | 192.168.56.22 | H2 database engine in server mode |
| `app` | 192.168.56.21 | Bookstore Spring Boot application |
| `proxy` | 192.168.56.20 | Nginx reverse proxy, the only entry point |

CA3 keeps the machines, the addresses and the network, and replaces every
shell provisioner with Ansible. Vagrant still creates the virtual machines;
Ansible describes the desired state of each one.

---

## 2. Environment and prerequisites

| Component | Version | Notes |
| --- | --- | --- |
| Host | Windows 11 Home, 16 GB RAM | Hyper-V enabled (WSL 2) |
| Vagrant | 2.4.9 | |
| VirtualBox | 7.2.20 | |
| Box | `bento/ubuntu-24.04` `202510.26.0` | Same pinned box as CA2 |
| Ansible | installed inside each guest by Vagrant | see [section 4.1](#41-running-ansible-from-a-windows-host) |

> On this host VirtualBox runs on top of Hyper-V, and a guest with two virtual
> CPUs froze under the Gradle build in CA2. The `app` machine is therefore
> started with `APP_CPUS=1`.

---

## 3. Repository layout

```text
CA3/
├── README.md            this report
├── Vagrantfile          the three machines and the Ansible provisioner
├── ansible/             synced to /vagrant/ansible in every guest
│   ├── ansible.cfg      project configuration (inventory, roles path)
│   ├── hosts.ini        static inventory: one group per tier
│   ├── site.yml         playbook: a baseline play and one play per tier
│   ├── group_vars/
│   │   └── all.yml      ports shared by every tier
│   └── roles/
│       ├── ssh_access/  custom SSH key per machine
│       ├── common/      packages, /etc/hosts, firewall baseline
│       └── h2/          H2 server on db
└── keys/                SSH key pairs generated on the host (not versioned)
```

---

## 4. Ansible provisioning

### 4.1. Running Ansible from a Windows host

> Use Ansible to deploy and configure the Bookstore application on the app VM
> [...] The configuration must preserve the multi-VM architecture established
> in CA2

Ansible needs a Linux or macOS control node; Windows is not supported, except
through WSL. On the group's host Vagrant runs on Windows, while WSL uses its
own NAT network and cannot reach the ports that Vagrant forwards on Windows.
Two options were considered:

| Option | What it requires | Decision |
| --- | --- | --- |
| `ansible` provisioner, run from WSL | Ansible in WSL, WSL in mirrored networking mode, Vagrant driven from WSL | Rejected: changes the configuration of the host and is hard to reproduce on another machine |
| `ansible_local` provisioner | Nothing on the host: Vagrant installs Ansible inside each guest and runs the playbook there | **Chosen** |

With `ansible_local`, each machine is its own control node. Vagrant runs the
same `site.yml` on every machine, limited to that machine, in the order
`db`, `app`, `proxy`, which is the order in which the tiers depend on each
other.

```ruby
node.vm.provision "ansible_local" do |ansible|
  ansible.provisioning_path = "/vagrant/ansible"
  ansible.config_file       = "ansible.cfg"
  ansible.inventory_path    = "hosts.ini"
  ansible.playbook          = "site.yml"
  ansible.limit             = name
  ansible.compatibility_mode = "2.0"
  ansible.extra_vars = {
    ssh_public_key: File.read("#{private_key}.pub").strip
  }
end
```

> - `provisioning_path` is the folder, inside the guest, where the playbook,
>   the inventory and `ansible.cfg` are. Only `CA3/ansible` is shared with the
>   guests, so the private keys in `CA3/keys` never leave the host.
> - `limit` restricts the run to the machine being provisioned.
> - `extra_vars` passes the public key generated on the host for this machine.
> - The share is mounted with `dmode=755,fmode=644`: VirtualBox shares are
>   world-writable by default, and Ansible ignores an `ansible.cfg` found in a
>   world-writable directory.

### 4.2. Static inventory

> Provide hosts.ini (static or the Vagrant auto-inventory path) and show
> ansible-inventory --list output. This ensures that the logical mapping
> between your Ansible inventory and the live Vagrant VMs is correctly
> established before playbook execution

A static inventory was preferred to the one Vagrant generates, because it is
versioned with the playbook and names the groups by tier:

```ini
[dbservers]
db ansible_host=192.168.56.22

[appservers]
app ansible_host=192.168.56.21

[proxyservers]
proxy ansible_host=192.168.56.20

[all:vars]
ansible_connection=local
```

> - Each host keeps the private address it had in CA2 in `ansible_host`, so
>   the address of every tier is defined once and other tiers can read it
>   (for example, the firewall of `db` needs the address of `app`).
> - `ansible_connection=local`: with `ansible_local`, the playbook always runs
>   on the machine it configures, so Ansible does not open an SSH connection.
> - The group names are plural. With `[db]` and a host `db`, Ansible warned
>   `Found both group and host with same name: db`.

`ansible.cfg` sets this file as the default inventory, so the commands run in
`/vagrant/ansible` need no `-i`:

```ini
[defaults]
inventory = hosts.ini
roles_path = roles
retry_files_enabled = False
interpreter_python = /usr/bin/python3
```

```bash
vagrant ssh proxy -c 'cd /vagrant/ansible && ansible-inventory --list'
```

```console
{
    "_meta": {
        "hostvars": {
            "app": {
                "ansible_connection": "local",
                "ansible_host": "192.168.56.21"
            },
            "db": {
                "ansible_connection": "local",
                "ansible_host": "192.168.56.22"
            },
            "proxy": {
                "ansible_connection": "local",
                "ansible_host": "192.168.56.20"
            }
        },
        "profile": "inventory_legacy"
    },
    "all": {
        "children": [
            "ungrouped",
            "dbservers",
            "appservers",
            "proxyservers"
        ]
    },
    "appservers": {
        "hosts": [
            "app"
        ]
    },
    "dbservers": {
        "hosts": [
            "db"
        ]
    },
    "proxyservers": {
        "hosts": [
            "proxy"
        ]
    }
}
```

> Every live VM appears in exactly one group, with the address Vagrant gave it
> on the private network. The same mapping can be read as a tree with
> `ansible-inventory --graph`.

### 4.3. First run: custom SSH key per machine

CA2 replaced the Vagrant insecure key with a key generated per machine, in
`provisioning/ssh-key.sh`. The same goal is now the first role of the
playbook:

```yaml
# ansible/site.yml
- name: Baseline of every machine
  hosts: all
  become: true
  roles:
    - ssh_access
```

```yaml
# ansible/roles/ssh_access/tasks/main.yml
- name: Accept only the custom SSH key for {{ ssh_access_user }}
  ansible.posix.authorized_key:
    user: "{{ ssh_access_user }}"
    key: "{{ ssh_access_public_key }}"
    exclusive: true
    state: present
```

> - `exclusive: true` removes every other key from `authorized_keys`, which is
>   what the 25 lines of `ssh-key.sh` did by comparing and rewriting the file.
> - The module compares the current file with the desired one, so it reports
>   `changed` only when it rewrote it.

```bash
APP_CPUS=1 vagrant up
```

```console
==> db: Running provisioner: ansible_local...
    db: Installing Ansible...
    db: Running ansible-playbook...

PLAY [Baseline of every machine] ***********************************************

TASK [Gathering Facts] *********************************************************
ok: [db]

TASK [ssh_access : Accept only the custom SSH key for vagrant] *****************
changed: [db]

PLAY RECAP *********************************************************************
db                         : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

> `app` and `proxy` produce the same recap. Vagrant installed `ansible-core
> 2.21.5` in each guest. Every run also prints
> `[DEPRECATION WARNING]: The '--inventory-file' argument is deprecated`: the
> option is added by Vagrant 2.4.9 itself when `inventory_path` is set, and
> does not affect the run.

The key is checked from the host: the custom key is accepted and the insecure
key is refused.

```console
db custom: db
db insecure: vagrant@127.0.0.1: Permission denied (publickey,password).
app custom: app
app insecure: vagrant@127.0.0.1: Permission denied (publickey,password).
proxy custom: proxy
proxy insecure: vagrant@127.0.0.1: Permission denied (publickey,password).
```

A second `vagrant provision` changes nothing:

```console
db                         : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
app                        : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
proxy                      : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 4.4. Modularity: roles and task files

> To ensure maintainability and readability, the use of modularity is
> required. At a minimum, your solution must split tasks into separate files
> using import_tasks or include_tasks. However, you are strongly encouraged to
> use Ansible Roles

Each CA2 script becomes one role with a single responsibility, and each role
splits its tasks into files by concern:

| CA2 script | Role | Task files |
| --- | --- | --- |
| `ssh-key.sh` | `ssh_access` | `main.yml` |
| `base.sh` | `common` | `packages.yml`, `hosts.yml`, `firewall.yml` |
| `db.sh` | `h2` | `install.yml`, `service.yml`, `firewall.yml` |

```yaml
# ansible/roles/h2/tasks/main.yml
- name: Install Java and the H2 engine
  ansible.builtin.import_tasks: install.yml

- name: Run H2 as a service
  ansible.builtin.import_tasks: service.yml

- name: Restrict the H2 port to the application tier
  ansible.builtin.import_tasks: firewall.yml
```

> - `import_tasks` was chosen over `include_tasks`. An import is resolved when
>   the playbook is parsed, so every imported task is listed by
>   `--list-tasks`, can be selected with `--start-at-task`, and inherits the
>   tags and conditions of the import. An include is resolved only when the
>   play reaches it, which is needed when the file name comes from a variable
>   or a loop. No task file here depends on runtime data, so the static form is
>   the simpler and more predictable one.
> - Each role keeps its configurable values in `defaults/main.yml` (lowest
>   precedence), its templates in `templates/` and its handlers in
>   `handlers/main.yml`. Values shared by several tiers, such as the H2 and
>   Bookstore ports, are in `group_vars/all.yml`.

The playbook has a baseline play for every machine and one play per tier:

```yaml
# ansible/site.yml
- name: Baseline of every machine
  hosts: all
  become: true
  roles:
    - ssh_access
    - common

- name: Database tier
  hosts: dbservers
  become: true
  roles:
    - h2
```

### 4.5. Common baseline: packages, names and firewall

`common` replaces `base.sh` and the firewall commands that every CA2 script
repeated:

```yaml
# ansible/roles/common/tasks/packages.yml
- name: Install {{ common_packages | join(', ') }}
  ansible.builtin.apt:
    name: "{{ common_packages }}"
    state: present
    update_cache: true
    cache_valid_time: 3600
  register: common_apt
  until: common_apt is succeeded
  retries: 5
  delay: 10
```

> - `until`/`retries` handle a transient condition seen on a fresh Ubuntu box:
>   `unattended-upgrades` can hold the dpkg lock during the first minutes, and
>   a mirror can fail for a moment. The task is retried up to 5 times, 10
>   seconds apart, before the run fails.
> - `cache_valid_time: 3600` refreshes the package index only when it is older
>   than one hour, so a second run does not report a change for it.

```yaml
# ansible/roles/common/tasks/hosts.yml
- name: List every machine of the inventory in /etc/hosts
  ansible.builtin.blockinfile:
    path: /etc/hosts
    marker: "# {mark} cogsi-ca3"
    block: |
      {% for host in groups['all'] | sort %}
      {{ hostvars[host].ansible_host }} {{ host }}
      {% endfor %}
```

> The addresses come from the inventory: adding a machine to `hosts.ini` is
> enough for every machine to resolve it.

The firewall closes every incoming port except SSH. Each tier opens its own
port in its own role.

### 4.6. H2 in server mode on db

> Use Ansible to deploy and configure H2 in server mode on the db VM

```yaml
# ansible/roles/h2/tasks/install.yml (download step)
- name: Download H2 {{ h2_version }}
  ansible.builtin.get_url:
    url: "{{ h2_url }}"
    dest: "{{ h2_jar }}"
    checksum: "sha1:{{ h2_sha1 }}"
    owner: root
    group: root
    mode: "0644"
  register: h2_download
  until: h2_download is succeeded
  retries: 3
  delay: 5
  notify: Restart h2
```

> `get_url` downloads only when the jar is missing or does not match the
> checksum published by Maven Central, and fails if a download is corrupted.
> The CA2 script implemented the same with `sha1sum --check`, a temporary file
> and a rename.

The systemd unit is the CA2 one, now a Jinja2 template
(`roles/h2/templates/h2.service.j2`) filled from the role defaults:

```ini
ExecStart=/usr/bin/java -cp {{ h2_jar }} org.h2.tools.Server -tcp -tcpAllowOthers -tcpPort {{ h2_port }} -baseDir {{ h2_data_dir }} -ifNotExists
```

```yaml
# ansible/roles/h2/tasks/service.yml (excerpt)
- name: Install the systemd unit
  ansible.builtin.template:
    src: h2.service.j2
    dest: /etc/systemd/system/h2.service
    owner: root
    group: root
    mode: "0644"
  notify: Restart h2

- name: Enable and start h2
  ansible.builtin.systemd_service:
    name: h2
    enabled: true
    state: started
    daemon_reload: true

- name: Apply pending restarts
  ansible.builtin.meta: flush_handlers

- name: Wait for H2 to listen on port {{ h2_port }}
  ansible.builtin.wait_for:
    port: "{{ h2_port }}"
    host: 127.0.0.1
    timeout: 60
```

> - The handler `Restart h2` runs only when the unit or the jar changed. On
>   the first run it restarts the service just started, which is harmless; on
>   later runs nothing is notified and H2 keeps running.
> - `flush_handlers` applies that restart before the port check, instead of at
>   the end of the play.
> - `wait_for` only proves that the port is open. The application-level
>   check, a real SQL query, is part of the health checks in a later section.

Only the application tier may reach the H2 port. The allowed addresses are
taken from the `appservers` group of the inventory:

```yaml
# ansible/roles/h2/defaults/main.yml
h2_allowed_clients: "{{ groups['appservers'] | map('extract', hostvars, 'ansible_host') | list }}"
```

```yaml
# ansible/roles/h2/tasks/firewall.yml
- name: Allow port {{ h2_port }} only from the application tier
  community.general.ufw:
    rule: allow
    from_ip: "{{ item }}"
    to_ip: "{{ ansible_host }}"
    port: "{{ h2_port | string }}"
    proto: tcp
  loop: "{{ h2_allowed_clients }}"
```

```bash
vagrant provision
```

```console
PLAY [Database tier] ***********************************************************

TASK [Gathering Facts] *********************************************************
ok: [db]

TASK [h2 : Install the Java runtime] *******************************************
changed: [db]

TASK [h2 : Create the installation directory] **********************************
changed: [db]

TASK [h2 : Download H2 2.4.240] ************************************************
changed: [db]

TASK [h2 : Create the h2 service account] **************************************
changed: [db]

TASK [h2 : Create the data directory] ******************************************
changed: [db]

TASK [h2 : Install the systemd unit] *******************************************
changed: [db]

TASK [h2 : Enable and start h2] ************************************************
changed: [db]

RUNNING HANDLER [h2 : Restart h2] **********************************************
changed: [db]

TASK [h2 : Wait for H2 to listen on port 9092] *********************************
ok: [db]

TASK [h2 : Allow port 9092 only from the application tier] *********************
changed: [db] => (item=192.168.56.21)

PLAY RECAP *********************************************************************
db                         : ok=19   changed=13   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
app                        : ok=8    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
proxy                      : ok=8    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

> The three recaps are printed by three separate runs, one per machine; they
> are shown together here. A second `vagrant provision` reports `changed=0` on
> the three machines.

```bash
vagrant ssh db -c 'systemctl is-active h2; sudo ufw status numbered'
vagrant ssh app -c 'nc -zv -w 3 db 9092'
vagrant ssh proxy -c 'nc -zv -w 3 db 9092'
```

```console
active
     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 192.168.56.22 9092/tcp     ALLOW IN    192.168.56.21
[ 3] 22/tcp (v6)                ALLOW IN    Anywhere (v6)

Connection to db (192.168.56.22) 9092 port [tcp/*] succeeded!

nc: connect to db (192.168.56.22) port 9092 (tcp) timed out: Operation now in progress
```

### 4.7. Secrets with Ansible Vault

> Sensitive credentials must not appear in logs. Use no_log: true on tasks
> that handle sensitive data to prevent their arguments and results from being
> exposed in Ansible output

In CA2 the database password was a plain environment variable with a default
value in the `Vagrantfile`. In CA3 it is encrypted with Ansible Vault:

```text
ansible/group_vars/all/
├── main.yml     db_password: "{{ vault_db_password }}"
└── vault.yml    vault_db_password, encrypted (AES256)
```

> - The `vault_` prefix makes it clear, in `main.yml`, which values come from
>   the vault, while the code uses the plain names (`db_password`).
> - The vault password is in `ansible/.vault_pass`, and the `Vagrantfile`
>   passes it to every run with `ansible.vault_password_file = ".vault_pass"`.
>
> **Why the vault password is versioned.** In a real project this file would
> never be committed: anyone with the repository could decrypt `vault.yml`.
> Here it is committed on purpose, so that the evaluator can reproduce the
> assignment with a plain `vagrant up`. This is acceptable only because both
> secrets are random values generated for this educational environment (a
> 32-character vault password and a 24-character database password), used
> nowhere else, and they protect a database that exists only inside the lab
> VMs. Ansible Vault and `no_log` still serve their purpose here: the password
> never appears in plaintext in the repository files or in the Ansible output.

The encrypted file was created inside a guest, where Ansible is installed,
without writing the plaintext to disk:

```bash
vagrant ssh db -c "cd /vagrant/ansible && printf 'vault_db_password: \"%s\"\n' '<db password>' \
  | ansible-vault encrypt --vault-password-file .vault_pass --output group_vars/all/vault.yml -"
```

Every task whose arguments or results contain the password is marked
`no_log: true`: the `application.properties` template on `app` and the SQL
health check on `db`, whose command line carries the password.

### 4.8. Bookstore on app and the health checks of app and db

> Include health-check tasks in your playbook to verify that each service is
> running correctly [...] A running process or an open port alone is not
> sufficient

The `bookstore` role replaces `app.sh`: it clones the group repository as the
unprivileged `bookstore` account, builds with the Gradle Wrapper only when the
source changed or no jar exists, deploys the jar and the
`application.properties` template (`no_log: true`), installs the systemd unit
that waits for the H2 port, and opens port 8080 only to the proxy tier.

| Tier | Check | Why it is application-level |
| --- | --- | --- |
| `db` | `org.h2.tools.Shell` runs `SELECT H2VERSION()` over TCP with the Bookstore credentials | the engine must accept the login and execute SQL |
| `app` | `/actuator/health` must be `UP`, then `/books` must return a JSON list of books with titles | `UP` includes the datasource check; `/books` reads rows from H2 |

```console
ok: [db] => {
    "msg": "H2 answered SELECT H2VERSION() on port 9092: 2.4.240"
}
ok: [app] => {
    "msg": "/actuator/health is UP; /books returned HTTP 200 with 2 book(s), first \"Clean Code\""
}
db                         : ok=20   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
app                        : ok=25   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
proxy                      : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

> - On the second run the build task is `skipped` (the source did not change)
>   and nothing else changes.
> - The first version of the check expected HATEOAS links (`_links`) in
>   `/books`; the Bookstore on `main` returns a plain JSON list, so the check
>   failed with HTTP 200. The condition was corrected to validate the list.
> - The database password was searched for in the output of four runs and
>   appears in none of them.
> - From `proxy`, `http://app:8080/books` answers 200; from `db` the
>   connection times out (ufw).

**Problem found: DNS inside the guests.** After the host changed network, a
run hung for 20 minutes on `apt`: the guests still used the DNS servers that
VirtualBox had relayed at boot (`192.168.1.254` and an IPv6 resolver), which
no longer answered. The `Vagrantfile` now sets
`vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]`, so the guests
resolve names through the Windows host.
