# Changelog

All notable changes to Mantle are recorded here using [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The compatibility policy is documented in [the release guide](docs/release.md).
No historical release is inferred from development commits or this initial changelog.

This Unreleased inventory describes reviewed preparation for a proposed first
release, including the existing feature baseline and candidate safety fixes.
It is not a published release record. Executable qualification of the combined
candidate, native/hosted gates and release integrity checks remain pending;
see [v1 readiness](docs/v1-readiness.md).

## [Unreleased]

### Added

- Portable Bash/Zsh activation and a separate native Fish runtime, with six
  capability profiles, XDG-aware state and quiet startup by default.
- Literal typed configuration, explicit environment overrides, focused alias
  groups, history policy, completions and opt-in shell extensions/presentation.
- The Mantle command dispatcher, command catalog and explicit installer discovery;
  storage inspection, project archives and HLS download commands.
- User-owned copy/symlink installation, marked shell hooks, diagnostics and
  explicit enable/disable/update/uninstall lifecycle commands.
- A portable release declaration, reviewable Task handoffs and a manual immutable Relay publication boundary.
- An optional inert installation receipt identifying the source revision, exact tag, source archive and release evidence.
- A proposed v1 readiness guide with local/native qualification commands, safe
  Mac alias preferences and application-specific relocation limits.
- Regression fixtures for installer hook/recovery failures, legacy/XDG selection,
  private runtime/Codex directories, native Fish safeguards and verifier Bash
  selection. These new fixtures have not yet executed for this candidate.

### Changed

- Shortened the README around current setup and support, preserving detailed usage
  in its reference guide and selecting the existing proposed presentation input.
- Recompute migration diagnostics per activation; preserve explicit tool roots
  and existing legacy/PATH state, including Claude standalone JSON, and recognize
  the current OpenHands CLI persistence override.
- Align Fish core XDG root/runtime handling and selected language/cache bindings;
  full Bash/Zsh tool, AI-state, cache and history parity remains incomplete.
- Local release archives refuse existing destinations, including competing publications.
- Release publication requires a reviewed current-default-branch candidate; immutable tags and assets are never replaced.
- Classify `~/.net` as application-owned partial single-file extraction support,
  rather than a universal assembly store that must remain under HOME.

### Fixed

- Honor explicitly supplied absolute ZDOTDIR throughout installer hook lifecycle
  operations; reject empty/relative values and invalid startup ancestors early.
- Refuse symlink/nonregular or malformed Bash/Zsh hooks before payload publication,
  preserve startup modes and leave unowned bytes unchanged on disable/uninstall.
- Track installer temporary roots, retain recoverable payload backups after
  interrupted/failed publication or restoration, preserve competing destinations,
  and propagate environment-diff initialization/capture failures.
- Reject final-component runtime and automatic Codex-root symlinks before chmod;
  require private owned defaults and preserve explicit CODEX_HOME. A real private
  runtime directory remains mandatory under ordinary-directory creation opt-out.
- Use the release verifier's invoking Bash for each installer lifecycle process,
  including the installed entrypoint, instead of reselecting via its shebang.

### Breaking changes

- Guarded tool/cache/history selection now preserves existing legacy paths
  even when XDG targets also exist, rather than silently preferring the XDG
  target. Broken legacy links remain visible. Select an explicit tool root to
  opt into XDG; startup does not merge, move or delete either location.
