# COGSI 2026-2027

Group repository for the Configuracao e Gestao de Sistemas (COGSI) course,
Mestrado em Engenharia Informatica, Instituto Superior de Engenharia do Porto.

## Assignments

| Folder | Assignment | Report |
| --- | --- | --- |
| `CA1/` | Build tools (Gradle, Ant alternative) | [CA1/README.md](CA1/README.md) |
| `CA2/` | Virtualization with Vagrant (Multipass and cloud-init alternative) | [CA2/README.md](CA2/README.md) |
| `CA3/` | Configuration management with Ansible (Puppet alternative) | [CA3/README.md](CA3/README.md) |
| `CA4/` | Containerization with Docker and Docker Compose (Podman alternative) | [CA4/README.md](CA4/README.md) |

## Layout

- `CA1/part1/` - Gradle demo chat application (Part 1).
- `CA1/part2/` - Bookstore Spring Boot application converted from Maven to Gradle (Part 2).
- `CA1/alternative/` - Bookstore Spring Boot application built with Ant and Ivy (alternative solution).
- `CA2/part1/` - Vagrant environment with one VM that builds and runs both CA1 applications (Part 1).
- `CA2/part2/` - Vagrant environment with three VMs: `db` (H2 server), `app` (Bookstore) and `proxy` (Nginx) (Part 2).
- `CA2/alternative/` - The Part 2 environment created with Multipass and cloud-init (alternative solution).
- `CA3/` - The CA2 Part 2 environment provisioned with Ansible roles (`CA3/ansible/`), and with Puppet as the alternative (`CA3/alternative/`).
- `CA4/part1/` - Docker images of the CA1 chat server and Bookstore, each built three ways (clone, host JAR, multi-stage) (Part 1).
- `CA4/part2/` - The CA2 Part 2 environment (`db`, `web`, `proxy`) with Docker Compose (Part 2).
- `CA4/alternative/` - The Part 2 environment with rootless Podman and Quadlet (alternative solution).

Each assignment has its technical report, written as a tutorial, in the
`README.md` of its folder.
