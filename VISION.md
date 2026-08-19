---
schema: aether.architecture-document/v1
id: mantle-vision
title: Mantle Vision
kind: architecture-document
version: 0.1.0
status: draft
owners:
  - egohygiene
created: 2026-08-19
updated: 2026-08-19
governed_by:
  - architecture-vision
depends_on:
  - mantle-purpose
related:
  - mantle-principles
  - mantle-pillars
  - mantle-manifesto
  - mantle-epistemology
supersedes: []
---

# Mantle Vision

## Vision statement

one modular shell foundation can initialize quietly and deterministically on macOS, Linux, Unix-compatible Windows environments, and containers.

## Desired future state

- The core capability is independently usable and documented.
- Interfaces are versioned, inspectable, and replaceable.
- Local, self-hosted, and managed contexts can compose the capability without hidden lock-in.
- People can understand consequential behavior before approving it.
- Organization integrations strengthen the standalone product rather than making it dependent on the suite.

## Intended transformation

The project moves its domain from fragmented, implicit, and manually coordinated behavior toward explicit contracts, reusable automation, and evidence-backed operation.

## Anti-vision

a shell replacement that takes over dotfiles, performs implicit privileged installation, or executes unverified remote scripts at startup.

## Directional signals

- A first-time user can explain the boundary after reading the architecture.
- A consumer can integrate through a stable public contract.
- A maintainer can reproduce and validate a release.
- A contributor can distinguish implemented, proposed, and unavailable capabilities.

## Evidence and uncertainty

- **Observed:** The repository README and checked-in implementation establish a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI.
- **Decided for this draft:** The repository owns the bounded concern described here and participates through versioned contracts.
- **Proposed:** Target systems and later roadmap phases remain proposals until accepted and implemented.
- **Open question:** Which parts of this draft should become active in the first independently versioned release?
