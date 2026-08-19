---
schema: aether.architecture-document/v1
id: mantle-ontology
title: Mantle Ontology
kind: architecture-document
version: 0.1.0
status: draft
owners:
  - egohygiene
created: 2026-08-19
updated: 2026-08-19
governed_by:
  - architecture-ontology
depends_on:
  - mantle-purpose
  - mantle-vision
  - mantle-principles
  - mantle-epistemology
related:
  - mantle-pillars
  - mantle-manifesto
  - mantle-ai-constitution
  - mantle-personal-model
supersedes: []
---

# Mantle Ontology

## Domain scope

Mantle models the concepts needed for give people a user-owned, portable shell runtime and installer framework that remains inspectable across platforms. The ontology names conceptual entities and relationships; it is not a source-code class model, API schema, or database design.

## Canonical concepts

| Concept | Meaning |
| --- | --- |
| Runtime entrypoint | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |
| Shell session | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |
| Module | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |
| Platform adapter | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |
| Environment variable | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |
| PATH entry | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |
| Installer | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |
| Command | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |
| Extension | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |
| Activation hook | A canonical concept in the Mantle domain whose exact fields belong to specifications or schemas, not this ontology. |

## Core relationships

- A repository or person provides source context to one or more domain artifacts.
- A specification constrains how an artifact is interpreted or produced.
- A plan separates proposed action from execution.
- Evidence supports a claim; a decision authorizes a durable direction.
- Provenance connects derived artifacts to their inputs and processing context.
- A consumer integrates through an explicit interface rather than internal structure.

## Boundaries

- Conceptual identity is distinct from filesystem path, database identifier, or display label.
- Observed state is distinct from desired state.
- Proposed relationships are not accepted facts.
- Neighboring repositories retain ownership of their domain concepts.

## Evidence and uncertainty

- **Observed:** The repository README and checked-in implementation establish a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI.
- **Decided for this draft:** The repository owns the bounded concern described here and participates through versioned contracts.
- **Proposed:** Target systems and later roadmap phases remain proposals until accepted and implemented.
- **Open question:** Which parts of this draft should become active in the first independently versioned release?
