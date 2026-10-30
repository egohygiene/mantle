# Changelog

All notable changes to Mantle are recorded here using [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The compatibility policy is documented in [the release guide](docs/release.md).
No historical release is inferred from development commits or this initial changelog.

## [Unreleased]

### Added

- A portable release declaration, reviewable Task handoffs and a manual immutable Relay publication boundary.
- An optional inert installation receipt identifying the source revision, exact tag, source archive and release evidence.

### Changed

- Local release archives refuse existing destinations, including competing publications.
- Release publication requires a reviewed current-default-branch candidate; immutable tags and assets are never replaced.
