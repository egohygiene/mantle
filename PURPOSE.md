---
schema: aether.architecture-document/v1
id: mantle-purpose
title: Mantle Purpose
kind: architecture-document
version: 0.1.0
status: draft
owners:
  - egohygiene
created: 2026-08-19
updated: 2026-08-19
governed_by:
  - architecture-purpose
depends_on:
  []
related:
  - mantle-vision
  - mantle-principles
  - mantle-pillars
  - mantle-manifesto
supersedes: []
---

# Mantle Purpose

## Purpose statement

Mantle exists to give people a user-owned, portable shell runtime and installer framework that remains inspectable across platforms.

## Need

shell configuration and workstation bootstrapping tend to become machine-specific, destructive, network-dependent, and difficult to test.

## Beneficiaries

- developers
- self-hosters
- Dev Container users
- CI environments
- Realm profiles

## Enduring value

The enduring value is a trustworthy, portable capability that remains useful when its implementation, delivery channel, or surrounding platform changes.

## Scope boundaries

Mantle owns a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI. It does not absorb neighboring repositories, treat temporary implementation choices as purpose, or claim authority beyond its explicit contracts.

## Evidence and uncertainty

- **Observed:** The repository README and checked-in implementation establish a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI.
- **Decided for this draft:** The repository owns the bounded concern described here and participates through versioned contracts.
- **Proposed:** Target systems and later roadmap phases remain proposals until accepted and implemented.
- **Open question:** Which parts of this draft should become active in the first independently versioned release?

## Open questions

- Which beneficiary needs require direct research before this document can become active?
- Which current features are incidental and should remain outside the enduring purpose?
