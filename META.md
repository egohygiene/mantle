---
schema: aether.architecture-document/v1
id: mantle-meta
title: Mantle Meta
kind: architecture-document
version: 0.1.0
status: draft
owners:
  - egohygiene
created: 2026-08-19
updated: 2026-08-19
governed_by:
  - architecture-meta
depends_on:
  - mantle-epistemology
  - mantle-ai-constitution
related:
  - mantle-purpose
  - mantle-vision
  - mantle-principles
  - mantle-pillars
supersedes: []
---

# Mantle Meta Architecture

## Architecture-system overview

Mantle's architecture is an 18-document graph materialized from the Aether architecture specifications. Each document owns one bounded concern. This index maps ownership and relationships without replacing the documents themselves.

## Document inventory

| Artifact | Path | Category | Status | Governing specification | Upstream dependencies |
| --- | --- | --- | --- | --- | --- |
| mantle-purpose | [PURPOSE.md](PURPOSE.md) | Identity | draft | architecture-purpose | — |
| mantle-vision | [VISION.md](VISION.md) | Identity | draft | architecture-vision | mantle-purpose |
| mantle-principles | [PRINCIPLES.md](PRINCIPLES.md) | Identity | draft | architecture-principles | mantle-purpose, mantle-vision |
| mantle-pillars | [PILLARS.md](PILLARS.md) | Identity | draft | architecture-pillars | mantle-purpose, mantle-vision, mantle-principles |
| mantle-manifesto | [MANIFESTO.md](MANIFESTO.md) | Identity | draft | architecture-manifesto | mantle-purpose, mantle-vision, mantle-principles, mantle-pillars |
| mantle-epistemology | [EPISTEMOLOGY.md](EPISTEMOLOGY.md) | Meta | draft | architecture-epistemology | mantle-purpose, mantle-principles |
| mantle-ai-constitution | [AI_CONSTITUTION.md](AI_CONSTITUTION.md) | Meta | draft | architecture-ai-constitution | mantle-purpose, mantle-vision, mantle-principles, mantle-epistemology |
| mantle-ontology | [ONTOLOGY.md](ONTOLOGY.md) | Domain | draft | architecture-ontology | mantle-purpose, mantle-vision, mantle-principles, mantle-epistemology |
| mantle-personal-model | [PERSONAL_MODEL.md](PERSONAL_MODEL.md) | Domain | draft | architecture-personal-model | mantle-purpose, mantle-vision, mantle-principles, mantle-epistemology, mantle-ontology |
| mantle-foundations | [FOUNDATIONS.md](FOUNDATIONS.md) | Foundation | draft | architecture-foundations | mantle-purpose, mantle-principles, mantle-epistemology |
| mantle-system | [SYSTEM.md](SYSTEM.md) | Foundation | draft | architecture-system | mantle-foundations, mantle-ontology |
| mantle-architecture | [ARCHITECTURE.md](ARCHITECTURE.md) | Foundation | draft | architecture-architecture | mantle-foundations, mantle-system |
| mantle-methodology | [METHODOLOGY.md](METHODOLOGY.md) | Foundation | draft | architecture-methodology | mantle-principles, mantle-epistemology, mantle-ai-constitution, mantle-foundations, mantle-architecture |
| mantle-design | [DESIGN.md](DESIGN.md) | Experience | draft | architecture-design | mantle-purpose, mantle-vision, mantle-principles, mantle-personal-model |
| mantle-design-system | [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | Experience | draft | architecture-design-system | mantle-personal-model, mantle-design |
| mantle-decisions | [DECISIONS.md](DECISIONS.md) | Governance | draft | architecture-decisions | mantle-principles, mantle-epistemology, mantle-foundations, mantle-system, mantle-architecture |
| mantle-roadmap | [ROADMAP.md](ROADMAP.md) | Foundation | draft | architecture-roadmap | mantle-vision, mantle-pillars, mantle-architecture, mantle-decisions |
| mantle-meta | [META.md](META.md) | Meta | draft | architecture-meta | mantle-epistemology, mantle-ai-constitution |

## Relationship graph

```mermaid
flowchart TD
  PURPOSE --> VISION --> PRINCIPLES --> PILLARS --> MANIFESTO
  PURPOSE --> EPISTEMOLOGY --> AI[AI Constitution]
  PRINCIPLES --> EPISTEMOLOGY
  EPISTEMOLOGY --> ONTOLOGY --> PERSONAL[Personal Model]
  PRINCIPLES --> FOUNDATIONS
  EPISTEMOLOGY --> FOUNDATIONS
  FOUNDATIONS --> SYSTEM --> ARCHITECTURE --> METHODOLOGY
  PERSONAL --> DESIGN --> DS[Design System]
  ARCHITECTURE --> DECISIONS --> ROADMAP
  PILLARS --> ROADMAP
  AI --> META
  EPISTEMOLOGY --> META
```

## Ownership map

- Identity documents own why the repository exists, its desired future, decision heuristics, strategic capabilities, and public commitments.
- Meta documents own knowledge integrity, AI authority, and navigation of this document system.
- Domain documents own canonical concepts and bounded human assumptions.
- Foundation documents own invariants, logical systems, structure, working method, and strategic evolution.
- Experience documents own intended experience and reusable semantic design language.
- Governance owns accepted architectural decisions and historical lineage.

## Reading order

1. PURPOSE, VISION, and PRINCIPLES.
2. EPISTEMOLOGY and ONTOLOGY.
3. FOUNDATIONS, SYSTEM, and ARCHITECTURE.
4. PERSONAL_MODEL, DESIGN, and DESIGN_SYSTEM when evaluating human-facing surfaces.
5. AI_CONSTITUTION before delegating consequential work.
6. DECISIONS and ROADMAP for accepted constraints and evolution.

## Authoring order

Follow the dependency graph from purpose through identity and evidence, then domain and foundations, experience, governance, roadmap, and finally this META index.

## Lifecycle and validation

All documents begin as draft and require human review before becoming active. Validation covers frontmatter, stable identifiers, links, graph acyclicity, ownership boundaries, evidence labels, Markdown structure, and agreement with repository reality.

## Change propagation

A material upstream change triggers review of every downstream node. Implementation changes first update the owning specification or decision when they alter durable behavior; META changes whenever inventory or relationships change.

## Gaps and omissions

- No document in this set is intentionally omitted because Mantle has repository, automation, human, AI, and public or documentation surfaces that justify the complete reference set.
- Target systems remain provisional where implementation evidence is absent.
- Repository-local schemas and automated graph validation should be added or connected to Aether in a later conformance pass.

## Evidence and uncertainty

- **Observed:** The repository README and checked-in implementation establish a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI.
- **Decided for this draft:** The repository owns the bounded concern described here and participates through versioned contracts.
- **Proposed:** Target systems and later roadmap phases remain proposals until accepted and implemented.
- **Open question:** Which parts of this draft should become active in the first independently versioned release?
