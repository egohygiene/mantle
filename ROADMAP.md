---
schema: aether.architecture-document/v1
id: mantle-roadmap
title: Mantle Roadmap
kind: architecture-document
version: 0.1.0
status: draft
owners:
  - egohygiene
created: 2026-08-19
updated: 2026-08-24
governed_by:
  - architecture-roadmap
depends_on:
  - mantle-vision
  - mantle-pillars
  - mantle-architecture
  - mantle-decisions
related:
  - mantle-purpose
  - mantle-principles
  - mantle-manifesto
  - mantle-epistemology
supersedes: []
---

# Mantle Roadmap

<!-- BEGIN ROADMAP EXECUTION SNAPSHOT -->
<!-- roadmap-manifest
schema: hygiene.roadmap/v1alpha1
repository: egohygiene/mantle
visibility: public
publication: central
route: /roadmap/mantle/
updated: 2026-08-24
-->
## 2026-08-24 execution snapshot

> This evidence-reconciled snapshot is the issue-generation and visual-roadmap handoff. The longer-horizon strategy below remains canonical context; generated HTML, JSON, progress, issue plans, and commit lists are projections.

**Lifecycle:** functional alpha  
**Current gate:** Make the default branch green and classify ownership and safety expectations for all 73 bin commands.  
**North-star outcome:** A portable, safe, versioned shell toolkit with explicit command ownership and predictable behavior.

### Visual roadmap publication

**Mode:** `central`  
**Route:** `/roadmap/mantle/`  
**Current publication evidence:** Source-only command suite; no package or tagged release observed.

Publish the public-safe projection through egohygiene.io at /roadmap/mantle/. This repository owns intent and acceptance evidence; it does not add a second site deployment.

### Quest line

<!-- roadmap-step
id: MAN-Q01
status: complete
depends_on: []
issues: []
-->
#### MAN-Q01 — Assemble the command suite

**State:** `complete`  
**Depends on:** None

**Outcome:** A broad functional shell-command surface exists.

**Exit criteria:**

- [x] Commands are present and executable from the declared bin surface.
- [x] The repository documents its alpha scope.

**Current evidence:**

- The audit counted 73 bin commands.

<!-- roadmap-step
id: MAN-Q02
status: blocked
depends_on: [MAN-Q01]
issues: []
-->
#### MAN-Q02 — Restore green shell quality

**State:** `blocked`  
**Depends on:** `MAN-Q01`

**Outcome:** The default branch passes formatting and shell quality checks.

**Exit criteria:**

- [ ] shfmt is green.
- [ ] A complete, non-cancelled main workflow run passes.

**Current evidence:**

- The audited shfmt check failed and the main run was cancelled.

<!-- roadmap-step
id: MAN-Q03
status: active
depends_on: [MAN-Q01]
issues: []
-->
#### MAN-Q03 — Classify command ownership and safety

**State:** `active`  
**Depends on:** `MAN-Q01`

**Outcome:** Every command has an owner, stability level, destructive-risk class, and test expectation.

**Exit criteria:**

- [ ] All 73 commands appear in a machine-readable inventory.
- [ ] Destructive commands require explicit safeguards and fixtures.

**Current evidence:**

- The 73-command surface was not fully classified.

<!-- roadmap-step
id: MAN-Q04
status: planned
depends_on: [MAN-Q02, MAN-Q03]
issues: [17]
-->
#### MAN-Q04 — Publish the first portable release

**State:** `planned`  
**Depends on:** `MAN-Q02`, `MAN-Q03`

**Outcome:** Issue #17 yields a reproducible, installable Mantle release.

**Exit criteria:**

- [ ] A tagged release includes checksums and installation guidance.
- [ ] A clean environment passes smoke tests for the supported command set.

**Current evidence:**

- Issue #17 tracks the release.
- No release was observed.

<!-- roadmap-step
id: MAN-Q05
status: planned
depends_on: [MAN-Q04]
issues: [18, 19, 20]
-->
#### MAN-Q05 — Complete storage boundaries and ecosystem adoption

**State:** `planned`  
**Depends on:** `MAN-Q04`

**Outcome:** Storage and archive work is complete, the Aniflow boundary is explicit, and Realm consumes a pinned release.

**Exit criteria:**

- [ ] Issues #18, #19, and #20 close with tests and ownership decisions.
- [ ] A Realm profile installs and verifies Mantle without copying its source.

**Current evidence:**

- Issues #18-#20 define storage, archive, and Aniflow boundary work.

### Roadmap-to-issue handoff

- A step is complete only when its exit criteria and required evidence are satisfied; commit count never determines progress.
- Ready or planned steps without an issue are candidates for the private, duplicate-aware roadmap.issue-plan.json dry run.
- Issue creation or reconciliation requires human approval or an explicitly authorized Pace operation and returns issue references through a reviewable roadmap pull request.
- Pull requests and commits should include Roadmap-Step: <ID>; historical evidence may be linked through existing issue and pull-request relationships.
- Public rendering uses only allowlisted build-time evidence and never places a GitHub token or private issue plan in the browser artifact.

<!-- END ROADMAP EXECUTION SNAPSHOT -->

## Strategic context

This roadmap describes capability evolution, not promised dates or an issue queue. Sequence follows architecture dependencies and may change when evidence or risk changes.

## Phase 1: Finalize installer and activation

**Outcome:** A bounded capability advances from documented intent to validated, independently usable behavior.

**Exit signals:**

- The owning contract and acceptance criteria are versioned.
- Implementation and documentation agree.
- Relevant tests and safety checks pass.
- Downstream consumers and migration impact are understood.
- Remaining uncertainty is visible.

## Phase 2: Complete platform conformance

**Outcome:** A bounded capability advances from documented intent to validated, independently usable behavior.

**Exit signals:**

- The owning contract and acceptance criteria are versioned.
- Implementation and documentation agree.
- Relevant tests and safety checks pass.
- Downstream consumers and migration impact are understood.
- Remaining uncertainty is visible.

## Phase 3: Harden XDG and privacy modules

**Outcome:** A bounded capability advances from documented intent to validated, independently usable behavior.

**Exit signals:**

- The owning contract and acceptance criteria are versioned.
- Implementation and documentation agree.
- Relevant tests and safety checks pass.
- Downstream consumers and migration impact are understood.
- Remaining uncertainty is visible.

## Phase 4: Publish versioned releases

**Outcome:** A bounded capability advances from documented intent to validated, independently usable behavior.

**Exit signals:**

- The owning contract and acceptance criteria are versioned.
- Implementation and documentation agree.
- Relevant tests and safety checks pass.
- Downstream consumers and migration impact are understood.
- Remaining uncertainty is visible.

## Phase 5: Integrate Realm projections and workstation automation

**Outcome:** A bounded capability advances from documented intent to validated, independently usable behavior.

**Exit signals:**

- The owning contract and acceptance criteria are versioned.
- Implementation and documentation agree.
- Relevant tests and safety checks pass.
- Downstream consumers and migration impact are understood.
- Remaining uncertainty is visible.

## Cross-cutting tracks

- Security, privacy, accessibility, licensing, and provenance.
- Documentation, architecture portals, examples, and onboarding.
- Packaging, release, compatibility, and self-hosting.
- Organization integration through explicit contracts.
- Observatory evidence and Pace conformance when those systems exist.

## Deferred direction

Optional managed services, enterprise controls, marketplaces, and the conversational organization compiler remain later architecture work. Current choices should preserve portability and avoid foreclosing them.

## Evidence and uncertainty

- **Observed:** The repository README and checked-in implementation establish a portable, modular shell environment and developer-tooling framework for local-first workstations, containers, and CI.
- **Decided for this draft:** The repository owns the bounded concern described here and participates through versioned contracts.
- **Proposed:** Target systems and later roadmap phases remain proposals until accepted and implemented.
- **Open question:** Which parts of this draft should become active in the first independently versioned release?
