---
schema: aether.architecture-document/v1
id: mantle-architecture
title: Mantle Architecture
kind: architecture-document
version: 0.1.0
status: draft
owners:
  - egohygiene
created: 2026-08-19
updated: 2026-10-18
governed_by:
  - architecture-architecture
depends_on:
  - mantle-foundations
  - mantle-system
related:
  - mantle-purpose
  - mantle-vision
  - mantle-principles
  - mantle-pillars
supersedes: []
---

# Mantle Architecture

## Purpose and scope

Mantle is a user-owned shell runtime with separate shell activation, command,
and installation paths. This document describes their checked-in structure,
dependency direction, and trust boundaries. [SYSTEM.md](SYSTEM.md) identifies
logical responsibilities; the feature guides define the detailed public
contracts. [PROVENANCE.md](PROVENANCE.md) records source lineage and imports.

## Public and internal surfaces

| Surface | Contract |
| --- | --- |
| `.shellrc` | Public source entrypoint for Bash and Zsh. |
| `runtime/shells/fish/runtime.fish` | Public native Fish entrypoint with explicit `MANTLE_ROOT`. |
| `bin/mantle` | Public process dispatcher for `mantle <command>`. |
| Flat `bin/` utilities | Existing external CLI contracts, with their own languages and dependencies. |
| `install.sh` | Public installation and lifecycle interface; manages only its owned payload and activation hooks. |
| `lib/core/`, `lib/bash/`, `lib/modules.sh` | Reusable shell functions and module-loading APIs; preserve tested public functions and source guards. |
| `lib/extensions/` | Optional libraries loaded explicitly into the caller's Bash/Zsh session. |
| `init/`, `modules/`, `platforms/`, internal runtime fragments | Runtime implementation reached through the appropriate shell entrypoint. |
| `libexec/mantle/`, `lib/install/` | Private command backends and installation implementation reached through public interfaces. |

An external command runs in its own process. It cannot initialize the caller's
shell, and its optional dependencies must not become shell-startup dependencies.
Public functions are not permission to execute arbitrary source-only files
directly or bypass their prerequisite loaders.

## Component responsibilities

| Component | Responsibility and dependency boundary |
| --- | --- |
| `init/` | Root/shell classification, deterministic initialization order, required-load failure propagation, and lifecycle state. It selects policies rather than defining their values. |
| `lib/core/`, `lib/bash/` | Reusable detection, guards, logging, PATH operations, and shell utilities. They do not dispatch public commands or own OS policy. |
| `lib/config/` | Parse versioned literal configuration, resolve policy precedence, and report value provenance. Configuration is data rather than shell code. |
| `lib/modules.sh` | Validate module names, load dependencies transactionally, reject cycles, and permit retry after a failed load. |
| `modules/` | Portable XDG, privacy, cache, tooling, environment, aliases, history, and explicit update-check policies. |
| `platforms/` | OS-specific path candidates and aliases applied after portable modules; no implicit installation or privilege changes. |
| `runtime/shared/`, `runtime/shells/` | Shared baseline and native shell adaptation. Fish remains an independent native implementation rather than sourcing Bash/Zsh code. |
| Profile metadata and resolver | Repository-owned `config/profiles.tsv`, resolved by portable Awk for shell startup. The graph selects capabilities before environment modules run. |
| `bin/mantle`, `libexec/mantle/commands/` | Resolve the correct installation, validate command names, expose help, and execute a command implementation in a child process. |
| Private Python backends | On-demand storage inspection, source archives, metadata introspection, and HLS downloading. They are outside shell initialization. |
| `lib/install/`, private installers | Shared platform/download/checksum/archive/filesystem primitives and tool-specific installation adapters. They do not provision container or project-service lifecycles. |
| `tests/`, `scripts/`, workflows | Behavioral contracts, isolated fixtures, static checks, release packaging, and verification evidence. |

Dependencies flow from entrypoints and orchestration toward reusable libraries
and policy adapters. Module/platform code uses the shared PATH primitives rather
than inventing a second mutation contract. Runtime libraries must not source a
public executable. CLI process dispatch is distinct from a source-time
dependency, including when an installer loads its private implementation.

[`config/architecture/layers.tsv`](config/architecture/layers.tsv) records the
owner and permitted source-time dependencies for maintained paths. The
architecture contract tests check classification and dependency direction;
on-demand Python backends are classified independently from shell startup.

## Shell initialization and failure state

The Bash/Zsh entrypoint resolves its physical installation root, detects the
active shell and interactivity, then enters `init/init.sh`. Initialization
validates the selected profile, loads required libraries and shell adapters,
defines the extension/module loaders, applies the portable module order, then
loads the OS adapter. Explicit extensions and eligible interactive policies
follow. [The profile guide](docs/profiles.md) owns the exact profile matrix and
initialization order.

The typed resolver overlays profile defaults with an optional literal config
file, then explicit environment overrides. `config/settings.tsv` defines the
setting vocabulary; `config/example.conf` is a user-editable starting point.
`mantle config` exposes validation and effective-value provenance without
initializing the caller's shell or executing config contents.

`workstation` remains the compatibility default. `core`, `container`, and `ci`
select a minimal foundation; `interactive` and `full` add their declared
capabilities. `MANTLE_PROFILE` selects startup policy, not command availability.
The validated `config/commands.json` catalog describes external command
applicability without installing dependencies or restricting dispatch.

Repeated initialization for the active profile is idempotent. Recursive loads
fail visibly, and a profile change requires a new shell. A failed required load
records failure and remains retryable; optional extension failures are reported
without claiming the extension loaded or failing unrelated setup. Native Fish
uses the same profile manifest/resolver and its own fragments and state.

Shell startup does not require Python, media tools, network requests, package
installation, or privilege prompts. Optional presentation runs only after the
required initialization succeeds, follows explicit opt-in and terminal gates,
and cannot turn a missing renderer into a failed shell. User-supplied
presentation configuration is trusted user code, outside the bundled profile's
offline guarantee.

`mantle startup` owns the shared presentation policy. `shell-banner` remains
the text/ANSI rendering utility and `mantle fastfetch` supplies offline data
collectors. The `private`, `share-safe`, `ci`, and `off` presentation modes are
additional policy gates; they do not enable automatic output without the
existing display opt-in. See [PRESENTATION.md](PRESENTATION.md).

## Command and publication boundaries

The dispatcher resolves its own installation and rejects an unrelated
`MANTLE_ROOT`. Public command wrappers support help and internal summaries
without optional dependencies; execution validates its own arguments and
requirements. Legacy utilities retain their individual compatibility contracts
instead of silently changing when a newer Mantle command is introduced.

| Operation | Boundary |
| --- | --- |
| [Storage](docs/storage.md) | Read-only local observations with no-follow filesystem traversal, explicit scan boundaries, and partial-result reporting. |
| [Archive](docs/archive.md) | Reviewable selection, exact exceptions, safe archive members, owned temporary state, and atomic no-overwrite publication. |
| [HLS download](docs/hls-download.md) | HTTP(S) request context, opaque loopback media gateway, credential-safe diagnostics, required-resource tracking, ffprobe validation, and no-overwrite publication. |
| [Installation](docs/release.md) | Owned prefixes and marked shell hooks, explicit version verification, update rollback, and preserved user startup content. |

Tool-specific installer resolution is recorded separately in
`config/installers.lock.tsv` and exposed through `mantle install --assurance`.
Native package-manager selection remains an explicit host-managed boundary;
an exact source-distribution version does not pin every operating-system
package. [The assurance guide](INSTALLER_ASSURANCE.md) describes those limits.

These operations have different authority and error contracts. A read-only
inspection does not authorize cleanup, an archive preview does not publish an
archive, and a downloaded media partial is not a validated final result.

## Ecosystem ownership and distribution

Mantle owns behavior inside a shell and reusable command/installation
primitives. Realm owns environment construction, container images, mounts,
ports, workspace lifecycle, and project services. Realm may provision optional
terminal packages and activate Mantle through a pinned public artifact; Mantle
must remain independently useful without Realm.

Empathy owns baseline composition and integration evidence, EgoLint owns lint
implementation, Relay owns reusable CI mechanics, and Aether owns reusable AI
specifications and policies. Consume sibling capabilities through released or
immutable public contracts rather than mutable copied source.

Canonical brand inputs remain under `.identity/`; generated packages under
`assets/identity/` are derived interfaces, as documented in
[the Identity guide](docs/identity.md). Generated output and historical audits
do not become source authority merely because they are committed.

The [release guide](docs/release.md) defines deterministic source-distribution
archives, exact version checks, signatures, and provenance verification. A
development symlink install intentionally depends on its source checkout;
deployed consumers should use an exact verified release artifact.

## Validation and change control

Linux/macOS and Bash/Zsh/Fish behavior are checked through the declared test
jobs and isolated local fixtures. MSYS2/Git Bash remains experimental; native
PowerShell is outside the runtime. A passing job or a local skip does not prove
coverage of an unexecuted platform or optional tool.

Before changing a boundary, identify its owner, preserve existing public APIs
or describe the compatibility change, update the relevant feature guide, and
run focused tests followed by the canonical suite. Keep source/migration
provenance recoverable. [CONTRIBUTING.md](CONTRIBUTING.md) and
[tests/README.md](tests/README.md) describe the contributor and validation
contracts. Architectural history remains in its existing records; source
consolidation does not retrospectively create accepted decisions.
