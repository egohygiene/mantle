# Runtime profiles and command catalog

Mantle supplies portable shell initialization, command-line utilities, and
installer primitives. A runtime profile chooses which shell policies are
initialized. It does not install dependencies or change the public executable
namespace.

## Choose a profile

Set `MANTLE_PROFILE` before sourcing Mantle. The default is `workstation`,
including in CI or a container, so existing activation hooks retain their
behavior. Consumers that need a minimal environment must select it explicitly.

| Profile | Inherits | Runtime responsibilities |
| --- | --- | --- |
| `core` | None | Shared libraries, XDG and privacy defaults, locale/editor defaults, user and Mantle executable paths, platform classification. |
| `interactive` | `core` | Shell ergonomics, aliases, history, and Fish functions/completions in an interactive shell. |
| `workstation` | `interactive` | Developer-tool configuration, language-tool paths, cache policy, and desktop platform paths. This is the compatibility default. |
| `container` | `core` | Minimal container foundation for Realm and other image consumers; no workstation tool configuration or automatic interactive setup. |
| `ci` | `core` | Minimal runner foundation; no workstation tool probes, interactive setup, or automatic startup display. |
| `full` | `workstation`, `container`, `ci` | Explicit union of the shipped capabilities for development and testing. Optional extensions and experimental features still require their own opt-ins. |

The manifest at [`config/profiles.tsv`](../config/profiles.tsv) defines ordered
parents and capabilities. Fields are separated by tabs; lists use colons and
`-` represents an empty list. It is repository-owned data, validated before
profile environment modules run. Parent capabilities are resolved first and
duplicates are removed while preserving their first occurrence. The shipped
six names and capability vocabulary form the current validated contract.

For Bash or Zsh:

```sh
export MANTLE_PROFILE="ci"
source "/path/to/mantle/.shellrc"
```

For Fish:

```fish
set -gx MANTLE_ROOT /path/to/mantle
set -gx MANTLE_PROFILE ci
source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"
```

`MANTLE_ACTIVE_PROFILE` records the selected profile and
`MANTLE_PROFILE_CAPABILITIES` records the resolved colon-separated capability
list. `mantle_profile_has "tooling"` tests a capability in the current shell.
Repeated sourcing with the same profile succeeds without repeating setup.
Changing profiles after successful initialization returns status `78`; start a
new shell with the desired profile so old policies are not left partially active.
An unknown profile or invalid manifest returns status `64`.

## Initialization order

The Bash/Zsh public entrypoint reconciles the existing files in this order:

1. Resolve the installation root and detect the shell and interactivity.
2. Validate and resolve the profile before loading environment modules. Then
   classify the platform/execution environment and load shared core libraries,
   the POSIX baseline, and the active Bash or Zsh adapter through
   `init/load-core.sh`.
3. Define extension and transactional module loaders.
4. Select environment modules from the canonical order `xdg`, `privacy`,
   `cache`, `tooling`, `environment`. Only profiles with `tooling` load `cache`
   and `tooling`; basic PATH construction remains available to every profile.
5. Load the platform runtime. Desktop paths and aliases require the appropriate
   workstation/interactive capability.
6. Load explicitly selected optional extensions in the requested order.
7. Load aliases and history only when the profile has `interactive` and the
   shell itself is interactive. Apply separately opted-in policies.
8. Record successful initialization, then consider the optional startup display
   only for an interactive-capable profile and eligible terminal session.

Fish uses the same manifest and Awk resolver, then native Fish environment and
privacy fragments, optional-extension diagnostics, and capability-gated native
interactive adaptations. It does not source the Bash/Zsh loaders or libraries.

Profile resolution uses portable Awk, with no Python or Bash subprocess needed
by Fish. Shell startup does not install tools or contact the network by default.
Missing or failed required runtime components fail initialization; optional
extension failures are reported without failing the shell. Existing module and
runtime source guards retain retry behavior for failed required loads.

## Optional extensions

The default extension selection is empty. For Bash/Zsh, request trusted shipped
extensions before activation:

```sh
export MANTLE_EXTENSIONS="github:wget"
source "/path/to/mantle/.shellrc"
```

Selections accept at most 32 lowercase extension identifiers separated by
colons. Invalid selections produce a warning without loading any selection.
Each successful extension is sourced once; missing or failed extensions warn
and are recorded in `MANTLE_FAILED_EXTENSIONS`. They do not prevent subsequent
extensions or shell initialization. `full` does not select extensions implicitly.

The existing explicit `mantle_load_extension "wget"` API remains available in
Bash/Zsh and returns a failure status to its caller. Extensions are trusted
shell code and must keep startup loading quiet, bounded, and free of implicit
network, installation, or privilege operations. Put those actions in functions
that users invoke deliberately. Fish does not source Bash extension files;
requested extensions produce a clear unsupported diagnostic and failure state.

## Consumption and ownership

Workstations can keep the normal installer and activation hook, optionally
setting a profile before that hook. The installer copies the manifest, resolver,
and catalog with the runtime payload. Symlink installations use the same data.

Realm images and devcontainers should install an exact Mantle release, set
`MANTLE_PROFILE=container`, and source the shell entrypoint where runtime
configuration is required. A CI job can use `MANTLE_PROFILE=ci` in a clean
noninteractive shell; the profile does not add prompts, aliases, language-manager
probes, or a startup dashboard. These profiles still respect inherited user
variables and PATH entries; they do not sanitize the caller's environment.

| Responsibility | Owner |
| --- | --- |
| Portable shell/runtime and CLI primitives | Mantle |
| Devcontainer and Compose orchestration | Realm |
| Lint implementation | EgoLint |
| GitHub reusable workflows and actions | Relay |
| AI specifications, skills, and policies | Aether |

A Mantle command may call another product without taking over its orchestration
or policy implementation.

## Shell and platform support

Mantle is Bash-first: Bash 3.2+ supplies the main reusable implementation, Zsh
uses an adapter, and Fish has native environment and interactive adaptations.
The shared POSIX runtime is a subset, not a standalone replacement for the
public entrypoints. Fish does not gain every Bash library or extension.

Linux and Darwin have platform adapters and native CI coverage. WSL uses Linux.
Windows support remains experimental for MSYS2/Git Bash and other supported Unix
tools; native PowerShell is outside this runtime. An unrecognized platform keeps
the portable core and reports no platform adapter rather than guessing one.
Profiles do not make an individual platform-specific utility portable.

## Command catalog

[`config/commands.json`](../config/commands.json) inventories executable flat
`bin/` entries and public `mantle` dispatcher commands. Installer implementations
remain discoverable through `mantle install --list` rather than duplicating each
installer in this catalog.

```sh
mantle profiles list
mantle profiles show ci --json
mantle profiles validate
mantle catalog list --profile ci --json
mantle catalog validate
```

The catalog records an ID, repository path, category, profile applicability,
platform applicability, dependencies, network/privilege metadata, and review
status. Inherited profile applicability is included in filtered listings.
`null` metadata means unknown, and `unreviewed` entries make no tested platform
or dependency promise. Legacy commands are kept in the inventory without
inventing an exhaustive audit. Reviewed entries should describe evidence-backed
requirements; evolve the schema only when it supports a real consumer.

Catalog profiles describe applicability, not access control: selecting `ci`
does not remove, rename, or block any command. External commands stay callable
from the same flat namespace. Validation rejects missing/stale executable
entries, duplicate IDs/paths, invalid profiles/platforms, malformed metadata,
and invalid profile graphs.

Python 3.9+ is required for profile/catalog inspection and validation commands,
not shell initialization or their help output. These CLI commands return `64`
for invalid usage, `69` for an unavailable dependency, and `78` for invalid
metadata, with errors on stderr. With the optional Task runner:

```sh
task profiles:list
task profiles:validate
task catalog:validate
task validate
task test
task doctor
```

`task validate` runs profile and catalog validation followed by the existing
static checks. `task test` delegates to the canonical test runner and
`task doctor` delegates to the existing installation diagnostics. The equivalent
`mantle` and `tests/run.sh` commands remain usable without Task.
