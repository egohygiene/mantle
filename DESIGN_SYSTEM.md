---
schema: aether.architecture-document/v1
id: mantle-design-system
title: Mantle Design System
kind: architecture-document
version: 1.0.0
status: active
owners:
  - egohygiene
created: 2026-08-19
updated: 2026-08-31
governed_by:
  - architecture-design-system
depends_on:
  - mantle-personal-model
  - mantle-design
related:
  - mantle-purpose
  - mantle-vision
  - mantle-principles
  - mantle-pillars
supersedes: []
---

# Mantle Design System

## Purpose and scope

This document defines reusable semantic language for Mantle's documentation, terminal output, diagrams, reports, sites, and future interactive surfaces. It does not freeze a framework, component library, or final visual identity.

## Semantic roles

| Role | Meaning |
| --- | --- |
| Canvas | Primary quiet background or base surface |
| Surface | Grouped content or bounded interaction area |
| Primary | Main action or navigational emphasis |
| Information | Neutral context or observation |
| Success | Completed and verified state |
| Caution | Review required; safe to pause |
| Danger | Destructive, security, privacy, or irreversible risk |
| Unknown | Missing, unavailable, partial, or unverified state |

## Status vocabulary

Use the states observed, planned, running, partial, verified, failed, blocked, and unknown consistently. Never present partial or unknown as success.

## Content and interaction

- Use verbs that describe the actual operation.
- Put scope and consequence before confirmation.
- Keep destructive actions visually and textually distinct.
- Pair errors with recovery and evidence locations.
- Preserve stable identifiers in machine-readable output.
- Respect reduced-motion and no-color contexts.

## Components and projections

Canonical patterns include command help, progress state, evidence table, decision card, plan preview, validation summary, architecture node, and recovery prompt. Concrete tokens and components are downstream projections maintained by the owning surface.

## Visual direction

Mantle's governed visual expression is terminal-native, quiet, dependable,
discoverable, and respectful of existing dotfiles. Three nested prompt layers
wrap a user-owned core. Cyan represents clear intent, violet represents
composition, and rose represents the human boundary inside the tooling. Deep
ink surfaces and high-contrast type keep the system calm and legible.

Canonical human-reviewed intent lives beneath [`.identity/`](.identity/).
Generated consumer assets live beneath [`assets/identity/`](assets/identity/)
and must verify against the pinned Identity toolchain before publication. See
the [Brand Kit integration guide](docs/identity.md).

## Evidence and uncertainty

- **Observed:** The repository README and checked-in implementation establish a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI.
- **Decided for this draft:** The repository owns the bounded concern described here and participates through versioned contracts.
- **Implemented:** Mantle adopts Identity v1 tokens, voice, usage, metadata,
  package, and repository-presentation contracts through issue #27.
- **Proposed:** The pinned Hygiene repository-presentation profile remains
  visibly proposed; consuming it does not claim certification or activation.
