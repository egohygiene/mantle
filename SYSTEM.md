---
schema: aether.architecture-document/v1
id: mantle-system
title: Mantle System
kind: architecture-document
version: 0.1.0
status: draft
owners:
  - egohygiene
created: 2026-08-19
updated: 2026-08-19
governed_by:
  - architecture-system
depends_on:
  - mantle-foundations
  - mantle-ontology
related:
  - mantle-purpose
  - mantle-vision
  - mantle-principles
  - mantle-pillars
supersedes: []
---

# Mantle System

## Purpose and scope

This document identifies Mantle's logical systems and responsibilities. It answers what the major systems do; [ARCHITECTURE.md](ARCHITECTURE.md) owns their structural organization and dependency rules.

## System inventory

| System | State | Responsibility |
| --- | --- | --- |
| Bash and Zsh entrypoint | Current | Owns its bounded portion of a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI; exposes explicit inputs, outputs, failure states, and evidence. |
| Fish runtime | Current | Owns its bounded portion of a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI; exposes explicit inputs, outputs, failure states, and evidence. |
| Shared loader | Current | Owns its bounded portion of a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI; exposes explicit inputs, outputs, failure states, and evidence. |
| Shell and platform modules | Current | Owns its bounded portion of a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI; exposes explicit inputs, outputs, failure states, and evidence. |
| Mantle CLI | Current or evolving | Owns its bounded portion of a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI; exposes explicit inputs, outputs, failure states, and evidence. |
| Installer framework | Current or evolving | Owns its bounded portion of a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI; exposes explicit inputs, outputs, failure states, and evidence. |
| Extension library | Current or evolving | Owns its bounded portion of a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI; exposes explicit inputs, outputs, failure states, and evidence. |
| Test matrix | Current or evolving | Owns its bounded portion of a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI; exposes explicit inputs, outputs, failure states, and evidence. |

## External systems

- Realm images and workstations
- Bash, Zsh, and Fish
- macOS, Linux, WSL, MSYS2, and Git Bash
- developer tools installed through adapters

External systems are integrations, not hidden implementation units. Each requires version, authentication, availability, data, error, and replacement boundaries appropriate to its risk.

## System interactions

Inputs enter through an adapter or validated contract, move through domain systems, produce artifacts and diagnostics, and leave through a stable interface. Evidence flows back to validation, review, and future decisions.

## Failure model

Systems fail closed at destructive, publication, privacy, and security boundaries. Partial results identify coverage and remain distinguishable from complete success.

## Evidence and uncertainty

- **Observed:** The repository README and checked-in implementation establish a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI.
- **Decided for this draft:** The repository owns the bounded concern described here and participates through versioned contracts.
- **Proposed:** Target systems and later roadmap phases remain proposals until accepted and implemented.
- **Open question:** Which parts of this draft should become active in the first independently versioned release?
