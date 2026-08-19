---
schema: aether.architecture-document/v1
id: mantle-design
title: Mantle Design
kind: architecture-document
version: 0.1.0
status: draft
owners:
  - egohygiene
created: 2026-08-19
updated: 2026-08-19
governed_by:
  - architecture-design
depends_on:
  - mantle-purpose
  - mantle-vision
  - mantle-principles
  - mantle-personal-model
related:
  - mantle-pillars
  - mantle-manifesto
  - mantle-epistemology
  - mantle-ai-constitution
supersedes: []
---

# Mantle Design

## Design philosophy

Mantle should feel terminal-native, quiet, dependable, discoverable, and respectful of existing dotfiles. Experience quality includes terminal, documentation, automation, generated artifacts, APIs, and recovery—not only graphical interfaces.

## Intended qualities

- **Orientation:** people can tell where they are, what is known, and what happens next.
- **Agency:** consequential choices are previewable, interruptible, and reversible where practical.
- **Truthfulness:** uncertainty, partial coverage, cost, and limitations remain visible.
- **Progressive disclosure:** simple journeys remain simple while evidence and advanced control stay reachable.
- **Continuity:** terms, states, commands, and visual language agree across surfaces.
- **Care:** accessibility, privacy, cognitive load, and recovery are baseline constraints.

## Core journey

The default journey is understand → configure → preview → act within authority → validate → inspect evidence → recover or continue. Read-only exploration remains available before commitment.

## Failure experience

Failures state what happened, what did not happen, whether partial output is safe, where evidence lives, and the smallest reliable recovery step. They never blame the person.

## Accessibility

Primary information is not encoded only by color, motion, iconography, or spatial position. Interfaces support keyboard access, meaningful focus, semantic structure, reduced motion, readable contrast, and plain-language alternatives.

## Evidence and uncertainty

- **Observed:** The repository README and checked-in implementation establish a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI.
- **Decided for this draft:** The repository owns the bounded concern described here and participates through versioned contracts.
- **Proposed:** Target systems and later roadmap phases remain proposals until accepted and implemented.
- **Open question:** Which parts of this draft should become active in the first independently versioned release?
