# COGSI 2026-2027

Group repository for the Configuracao e Gestao de Sistemas (COGSI) course,
Mestrado em Engenharia Informatica, Instituto Superior de Engenharia do Porto.

## Assignments

| Folder | Assignment | Report |
| --- | --- | --- |
| `CA1/` | Build tools (Gradle, Ant alternative) | [CA1/README.md](CA1/README.md) |
| `CA2/` | Virtualization with Vagrant (Multipass and cloud-init alternative) | [CA2/README.md](CA2/README.md) |

## Layout

- `CA1/part1/` - Gradle demo chat application (Part 1).
- `CA1/part2/` - Bookstore Spring Boot application converted from Maven to Gradle (Part 2).
- `CA1/alternative/` - Bookstore Spring Boot application built with Ant and Ivy (alternative solution).
- `CA2/part1/` - Vagrant environment with one VM that builds and runs both CA1 applications (Part 1).
- `CA2/part2/` - Vagrant environment with three VMs: `db` (H2 server), `app` (Bookstore) and `proxy` (Nginx) (Part 2).
- `CA2/alternative/` - The Part 2 environment created with Multipass and cloud-init (alternative solution).

Each assignment has its technical report, written as a tutorial, in the
`README.md` of its folder.
