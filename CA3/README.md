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
│   ├── site.yml         playbook
│   └── roles/
│       └── ssh_access/  custom SSH key per machine
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
