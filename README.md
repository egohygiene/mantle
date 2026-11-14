<p>
  <img src="assets/identity/repository-presentation/assets/banner-dark-1600.svg" alt="Mantle repository banner with a layered shell prompt mark" width="100%" />
</p>

# Mantle

A portable, user-owned shell environment and command-line toolkit for local
workstations, containers and CI. Mantle configures shell sessions through
explicit runtime layers and keeps tool installation behind commands you invoke.

**Status:** pre-release development (`0.1.0-dev`). No tagged Mantle release is
published. The checked-in release workflow and packaging tools prepare a future
release; they do not establish publication or general production readiness.

[Quick start](#quick-start) · [Usage](docs/usage.md) ·
[Architecture](ARCHITECTURE.md) · [Validation](tests/README.md) ·
[Release and recovery](docs/release.md) · [Roadmap](#roadmap)

## What you can use

- Bash/Zsh activation and a separate native Fish runtime, with six selectable
  [profiles](docs/profiles.md), XDG paths and literal configuration.
- The `mantle` command dispatcher, installer discovery and explicit installation
  [assurance](INSTALLER_ASSURANCE.md).
- Read-only [storage inspection](docs/storage.md), filtered
  [project archives](docs/archive.md) and [HLS downloads](docs/hls-download.md).
- Opt-in shell extensions and an offline
  [startup presentation](PRESENTATION.md), with quiet startup by default.

[The usage reference](docs/usage.md) contains command examples, configuration
keys, RubyGems behavior, completions, extensions and initialization details.

## Quick start

Use Git and Bash 3.2+ or Zsh to try the current source in one shell session:

```sh
git clone "https://github.com/egohygiene/mantle.git"
cd "mantle"
source "./.shellrc"
mantle help
mantle version
```

This initializes the current session without replacing startup files. Use a new
shell session to return to your previous environment. To choose a smaller
profile, set `MANTLE_PROFILE=core`, `container` or `ci` before activation; the
compatibility default is `workstation`.

For Fish, replace the `source` line with the native entrypoint:

```fish
set -gx MANTLE_ROOT (pwd)
source "./runtime/shells/fish/runtime.fish"
```

For an explicit user-owned copy installation, preview the changes first:

```sh
./install.sh --dry-run --shell bash
./install.sh --shell bash
```

The installer manages its marked activation block. `--no-shell-hook` skips
startup-file changes for containers and CI; `--method symlink` selects explicit
development mode. The [installation and recovery guide](docs/release.md)
explains status, doctor, disable, update, uninstall and rollback. Its future
release-download examples require an actually published, independently verified
release; use the source checkout above during development.

## Support and requirements

Bash and Zsh share `.shellrc`; Fish uses its native runtime. Linux/WSL and macOS
have platform adapters and test jobs. Windows support is experimental and
limited to MSYS2/Git Bash; native PowerShell is outside the supported surface.
Platform declarations and workflow files do not prove a particular run passed.
See [platform notes](platforms/README.md), the
[profile support matrix](docs/profiles.md#shell-and-platform-support) and the
[Test Suite workflow](.github/workflows/test.yml) for the exact boundaries.

Shell initialization and copy installation do not require Python. Python 3.9+
is needed for storage, archives, profile/catalog JSON inspection, HLS commands
and release packaging. HLS downloading additionally requires FFmpeg/ffprobe
with segment retry support (FFmpeg 6.1+). Optional tool prerequisites remain
command-specific; inspect `mantle help <command>` before use.

Report ordinary bugs or feature requests through
[GitHub issues](https://github.com/egohygiene/mantle/issues). This repository does
not currently document a private vulnerability-reporting channel; do not put
credentials or private machine data into a public issue. The
[security and privacy boundaries](docs/usage.md#security-and-privacy) describe
startup behavior and user-owned state.

## Develop and validate

Run the canonical commands from the repository root:

```sh
./bin/mantle profiles validate
./bin/mantle catalog validate
./tests/run.sh
```

[The test guide](tests/README.md) documents required tools, isolated fixtures,
static checks and the strict tool-complete suite (`./tests/run.sh --strict`).
Optional local skips do not qualify their missing tools or platforms. The
[contribution guide](CONTRIBUTING.md) covers source ownership, portability,
formatting and focused changes. Reusable behavior stays in Mantle's canonical
layers; the [architecture](ARCHITECTURE.md) and [system map](SYSTEM.md) explain
those boundaries.

## Roadmap

[Execution tracker #45](https://github.com/egohygiene/mantle/issues/45) owns the
current issue queue and acceptance state. [ROADMAP.md](ROADMAP.md) preserves
strategy and dated snapshots; [CONTINUITY.md](CONTINUITY.md) records the current
handoff. Release acceptance remains under
[#26](https://github.com/egohygiene/mantle/issues/26), including supported-platform
qualification, authentic signing/provenance and separately approved publication.
Optional Flow integration and ADR-history work retain their upstream gates.

## Identity and license

The banner reuses Mantle's generated Identity package. The
[Identity guide](docs/identity.md#readme-reference-and-local-deviations) records
the selected Hygiene presentation reference, exact revision, proposed status
and local presentation decisions. It is a reference, not certification.
[PROVENANCE.md](PROVENANCE.md) preserves source lineage and artwork notices.

Mantle is available under the [MIT License](LICENSE). It builds on shell/Unix
and XDG conventions, Bats and ShellCheck; upstream and generated-material
attributions remain in the provenance record.
