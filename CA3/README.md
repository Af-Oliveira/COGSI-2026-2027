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
│   ├── group_vars/all/
│   │   ├── main.yml     ports and database settings shared by every tier
│   │   └── vault.yml    database password, encrypted with Ansible Vault
│   ├── .vault_pass      Ansible Vault password (see section 4.7)
│   └── roles/
│       ├── ssh_access/  custom SSH key per machine
│       ├── common/      packages, /etc/hosts, firewall baseline
│       ├── h2/          H2 server on db
│       ├── users/       developers group and devuser
│       ├── pam/         password policy, history and lockout
│       ├── bookstore/   Bookstore on app
│       └── nginx/       reverse proxy on proxy
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

### 4.9. Nginx on proxy and the forwarding health check

> Use Ansible to deploy and configure Nginx on the proxy VM as a reverse proxy
> for the Bookstore application running on the app VM [...] On proxy, confirm
> that Nginx responds successfully and correctly forwards requests to the
> Bookstore application running on app

The `nginx` role replaces `proxy.sh`. The CA2 site becomes the template
`roles/nginx/templates/bookstore.conf.j2`; the upstream is the first host of
`appservers` and its port the shared `app_port`.

```yaml
# ansible/roles/nginx/tasks/site.yml (excerpt)
- name: Write the {{ nginx_site_name }} site
  ansible.builtin.template:
    src: bookstore.conf.j2
    dest: "/etc/nginx/sites-available/{{ nginx_site_name }}"
  notify: Reload nginx

- name: Validate the Nginx configuration
  ansible.builtin.command: nginx -t
  changed_when: false
```

> - The site, its link in `sites-enabled` and the removal of the default site
>   all notify the handler `Reload nginx`, so Nginx is reloaded once, and
>   only when one of them changed.
> - `nginx -t` runs before the handlers are flushed: a broken template fails
>   the run instead of being loaded. It never changes anything, hence
>   `changed_when: false`.

A `200` from Nginx would not prove that it reaches the Bookstore, so the
health check compares the answer obtained through the proxy with the answer
obtained directly from `app`:

```yaml
# ansible/roles/nginx/tasks/health.yml (excerpt)
- name: Check that Nginx returned the Bookstore response
  ansible.builtin.assert:
    that:
      - nginx_books.json == nginx_upstream_books.json
```

```console
TASK [nginx : Check that Nginx returned the Bookstore response] ****************
ok: [proxy] => {
    "msg": "Nginx on port 80 forwards to app:8080: 2 book(s), same as the direct request"
}

PLAY RECAP *********************************************************************
proxy                      : ok=20   changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

The second run reports `proxy : ok=19 changed=0`. From the host, the proxy is
the entry point of the environment:

```bash
curl.exe -s http://localhost:8080/books
```

```console
[{"author":"Robert C. Martin","id":1,"price":30.0,"title":"Clean Code"},{"author":"Joshua Bloch","id":2,"price":40.0,"title":"Effective Java"}]
```

The check was also run with the Bookstore stopped on `app`, to confirm that it
detects a proxy that answers but cannot forward:

```bash
vagrant ssh app -c 'sudo systemctl stop bookstore'
vagrant provision proxy
```

```console
FAILED - RETRYING: [proxy]: nginx : Request the books through Nginx (9 retries left).
...
fatal: [proxy]: FAILED! => {"attempts": 10, "changed": false, "content": "<html>\r\n<head><title>502 Bad Gateway</title></head> ...
proxy                      : ok=16   changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
```

### 4.10. The developers group, devuser and the service accounts

> Use Ansible to create a group called developers and a user called devuser on
> the app and db VMs. Add devuser to the developers group. Place the Bookstore
> application on app and the database file on db in directories whose access
> permissions restrict access to members of the developers group [...] Ensure
> that service accounts have the permissions required to run the application
> and access the database. Use group membership, ownership, or ACLs as
> appropriate

A play applies the `users` role to `app` and `db` before the tier roles, so
the group exists when the services are configured:

```yaml
# ansible/site.yml (excerpt)
- name: Developers and access control on app and db
  hosts: dbservers:appservers
  become: true
  roles:
    - users
```

```yaml
# ansible/roles/users/tasks/main.yml (excerpt)
- name: Create {{ users_devuser }} as a member of {{ users_group }}
  ansible.builtin.user:
    name: "{{ users_devuser }}"
    shell: /bin/bash
    create_home: true
    groups: "{{ users_group }}"
    append: true
    password: "{{ devuser_password | password_hash('sha512', devuser_password_salt) }}"
    update_password: on_create
    state: present
  no_log: true
```

> - The password and the salt are in the vault. With a fixed salt the hash is
>   always the same, so the task is idempotent; with a random salt every run
>   would produce a new hash and report `changed`.
> - `update_password: on_create` sets the password only when the account is
>   created. A password changed later by the user (the PAM tests do it) is
>   not reverted by the next run.
> - `no_log: true` hides the arguments of the task, which contain the hash:
>   the output only shows `changed: [db]`.

**Group membership was chosen over ACLs.** Each directory has a single owner
and a single group that needs access, which ordinary permissions express
exactly; ACLs would add a second permission model to audit for no gain.

| Machine | Path | Owner:group | Mode | Who gets in |
| --- | --- | --- | --- | --- |
| `app` | `/opt/bookstore` | `root:developers` | `0750` | root, `devuser`, `bookstore` |
| `app` | `/opt/bookstore/bookstore.jar` | `root:developers` | `0640` | read only |
| `app` | `/etc/bookstore` | `root:bookstore` | `0750` | root and the service only: it holds the database password |
| `db` | `/var/lib/h2` | `h2:developers` | `2770` | root, `devuser`, `h2` |
| `db` | `/var/lib/h2/bookstore.mv.db` | `h2:developers` | `0660` | read and write for the group |

> - The service accounts `bookstore` and `h2` are added to `developers`
>   (`groups: developers`, `append: true`), which is what lets them keep
>   reading the jar and writing the database once the directories belong to
>   the group.
> - On `db`, the setgid bit (`2770`) and `UMask=0007` in `h2.service` make
>   every file that H2 creates belong to `developers` and stay closed to
>   others. The database file created before this change was moved to the
>   group by a `find` + `file` loop.
> - The jar is root-owned: the service can run it but not replace it.

```console
$ vagrant ssh db
developers:x:1001:devuser,h2
drwxrws--- 2 h2 developers 4096 Oct 26 16:11 /var/lib/h2
-rw-rw---- 1 h2 developers 65536 Oct 26 17:49 bookstore.mv.db
-- devuser:
bookstore.mv.db
-- vagrant (not in developers):
ls: cannot open directory '/var/lib/h2': Permission denied
active

$ vagrant ssh app
drwxr-x--- 2 root developers 4096 Oct 26 16:51 /opt/bookstore
-rw-r----- 1 root developers 55806170 Oct 26 16:51 bookstore.jar
-- devuser:
-rw-r----- 1 root developers 55806170 Oct 26 16:51 bookstore.jar
cat: /etc/bookstore/application.properties: Permission denied
-- vagrant:
ls: cannot open directory '/opt/bookstore': Permission denied
active
```

The first run after this change restarted `h2` (new unit) and `bookstore`
(new jar group), and the health checks waited for both. The next run reported
`changed=0` on the three machines. The book count grew from 2 to 6 across
these restarts: the Bookstore seeds its sample data on every start, a
behaviour of the application already described in CA2, not of the
provisioning.

### 4.11. PAM password policy, history and account lockout

> Use Ansible to configure PAM to enforce a complex password policy on the app
> and db VMs: minimum length of 12 characters; at least three of the four
> character classes [...] do not simply require all four; prevent reuse of
> the last five passwords; after five consecutive failed login attempts, the
> account should be locked for ten minutes [...] Document the PAM modules and
> configuration files used to enforce password history and account lockout,
> explaining any distribution-specific differences

The `pam` role runs on `app` and `db`, in the same play as `users`.

**Modules and files.**

| Rule | PAM module | Stack file | Options file | Options |
| --- | --- | --- | --- | --- |
| Length and classes | `pam_pwquality.so` (package `libpam-pwquality`) | `common-password` | `/etc/security/pwquality.conf` | `minlen = 12`, `minclass = 3`, `retry = 3`, `enforce_for_root` |
| History | `pam_pwhistory.so` (in `libpam-modules`) | `common-password` | `/etc/security/pwhistory.conf` | `remember = 5`, `enforce_for_root`; old hashes in `/etc/security/opasswd` |
| Lockout | `pam_faillock.so` (in `libpam-modules`) | `common-auth`, `common-account` | `/etc/security/faillock.conf` | `deny = 5`, `unlock_time = 600`, `fail_interval = 900`; records in `/var/run/faillock` |

> - `minclass = 3` with the `*credit` options left at 0 accepts any three
>   classes. The lecture example, `lcredit=-1 ucredit=-1 dcredit=-1
>   ocredit=-1`, would require all four, which the assignment rules out.
> - The options are in each module's own configuration file, so the PAM lines
>   stay short and are not edited by hand.
> - `enforce_for_root` makes the rules apply also when root sets a password
>   (`passwd devuser`, `chpasswd`), which is how the tests below change it.

**How the modules enter the stack on Ubuntu 24.04.** Debian and Ubuntu build
`/etc/pam.d/common-*` with `pam-auth-update` from the profiles in
`/usr/share/pam-configs/`; a hand edit of those files is overwritten the next
time a PAM package is upgraded. `libpam-pwquality` ships its own profile, but
Ubuntu 24.04 ships none for `pam_pwhistory` or `pam_faillock`, so the role
installs three profiles and lets `pam-auth-update` place the lines and compute
the `success=N` jumps:

```text
# /usr/share/pam-configs/faillock_notify   (Priority 1024: before pam_unix, 256)
Auth:     requisite  pam_faillock.so preauth
Account:  required   pam_faillock.so

# /usr/share/pam-configs/pwhistory         (Priority 1000: after pwquality, before pam_unix)
Password: requisite  pam_pwhistory.so use_authtok

# /usr/share/pam-configs/faillock          (Priority 0: after pam_unix)
Auth:     [default=die]  pam_faillock.so authfail
          sufficient     pam_faillock.so authsucc
```

```yaml
# ansible/roles/pam/tasks/stack.yml (excerpt)
- name: Enable the profiles with pam-auth-update
  ansible.builtin.command:
    argv: "{{ ['pam-auth-update', '--package', '--enable'] + pam_profiles }}"
  when: >-
    pam_profile_files is changed or
    'pam_faillock.so preauth' not in pam_stack_text or
    ...
  changed_when: true
```

> `pam-auth-update` is a command, so the role makes it idempotent itself: it
> runs only when a profile changed or a module is missing from the generated
> files. A final `assert` checks the order of the modules.

The resulting stack (comments removed):

```text
# common-auth
auth     requisite                    pam_faillock.so preauth
auth     [success=3 default=ignore]   pam_unix.so nullok try_first_pass
auth     [default=die]                pam_faillock.so authfail
auth     sufficient                   pam_faillock.so authsucc
auth     requisite                    pam_deny.so
auth     required                     pam_permit.so

# common-account
account  required                     pam_faillock.so
account  [success=1 new_authtok_reqd=done default=ignore]  pam_unix.so

# common-password
password requisite                    pam_pwquality.so retry=3
password requisite                    pam_pwhistory.so use_authtok
password [success=1 default=ignore]   pam_unix.so obscure use_authtok try_first_pass yescrypt
```

> **Problem found.** The first version put `account required pam_faillock.so`
> in the low-priority profile. `pam-auth-update` placed it after
> `pam_unix.so`, whose `success=2` jumped over it, so it would never run after
> a successful login. Moving the account line to the high-priority profile put
> it before `pam_unix.so`; the `assert` now checks that order.

**Distribution-specific differences.**

| | Debian / Ubuntu | RHEL / Fedora / Rocky |
| --- | --- | --- |
| Stack files | `/etc/pam.d/common-auth`, `common-account`, `common-password` | `/etc/pam.d/system-auth`, `password-auth` |
| Tool that writes them | `pam-auth-update` + profiles in `/usr/share/pam-configs` | `authselect` (older: `authconfig`) |
| Lockout | `pam_faillock` (since Ubuntu 22.04; older releases used `pam_tally2`) | `authselect enable-feature with-faillock` |
| History | profile written by hand, as here | `authselect enable-feature with-pwhistory` |
| Quality | `libpam-pwquality` adds its own profile | `pam_pwquality` is in the default profile |
| Option files | `/etc/security/{pwquality,pwhistory,faillock}.conf` | same files |

On a RHEL family host the role would install the same three `.conf` files
and replace the profiles with `authselect` features; this is where an
`include_tasks` chosen by `ansible_os_family` would fit.

**Tests on `app`** (the same role is applied to `db`). Every password change
goes through `common-password`; root runs `chpasswd` and `enforce_for_root`
applies the rules:

```console
== length and character classes
Ab1!xyz (7 chars, 4 classes)               -> REFUSED: BAD PASSWORD: The password is shorter than 12 characters
abcdefghijklmn (14 chars, 1 class)         -> REFUSED: BAD PASSWORD: The password contains less than 3 character classes
laranja!cometa%sol (lower, symbol)         -> REFUSED: BAD PASSWORD: The password contains less than 3 character classes
Tulipa7Marte9Rio (upper, lower, digit)     -> ACCEPTED
Laranja!Cometa%Sol (upper, lower, symbol)  -> ACCEPTED
Girassol42Vento! (4 classes)               -> ACCEPTED
== history (remember=5)
Hist0ryPass-01 .. Hist0ryPass-05 (new)     -> ACCEPTED
Hist0ryPass-01 (reuse of #1)               -> REFUSED: Password has been already used. Choose another.
Hist0ryPass-03 (reuse of #3)               -> REFUSED: Password has been already used. Choose another.
Hist0ryPass-06 (new #6)                    -> ACCEPTED
```

> `Abcdefghij1234` (three classes) was also refused, but by the dictionary
> check of `pam_pwquality` ("too simplistic/systematic"), not by the class
> rule; that check is on by default and was kept.

The lockout is tested over SSH from `proxy` to `app`, with `sshpass`
installed on `proxy` only for the test and removed afterwards:

```console
attempt 1 (wrong password): Permission denied, please try again.
...
attempt 5 (wrong password): Permission denied, please try again.
attempt 6 (correct password): Permission denied, please try again.

$ sudo faillock --user devuser
devuser:
When                Type  Source                                           Valid
2026-10-26 18:07:35 RHOST 192.168.56.20                                        V
2026-10-26 18:07:39 RHOST 192.168.56.20                                        V
2026-10-26 18:07:44 RHOST 192.168.56.20                                        V
2026-10-26 18:07:46 RHOST 192.168.56.20                                        V
2026-10-26 18:07:50 RHOST 192.168.56.20                                        V

$ sudo grep pam_faillock /var/log/auth.log
app sshd[24016]: pam_faillock(sshd:auth): Consecutive login failures for user devuser account temporarily locked

$ sudo faillock --user devuser --reset      # instead of waiting the 600 s
after reset (correct password): logged in as devuser
```

> - The sixth attempt uses the correct password and is refused: the account
>   is locked, not just the password rejected.
> - Vagrant and Ansible are not affected: they log in with the SSH key, which
>   does not go through the password check, and `sudo` is configured without
>   a password for `vagrant`.

The first run of the role reported `changed=6` on `db`; the second run
reported `changed=0` on both machines.
