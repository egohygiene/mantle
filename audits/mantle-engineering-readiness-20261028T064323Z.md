# Mantle engineering-readiness audit — 2026-10-28

**Outcome:** Mantle's existing runtime and command surfaces are already substantial. Finish three focused validation follow-ups and the existing release boundary; leave Flow shortcuts and ADR-history adoption optional. No new shell framework, UI platform, or content reorganization is needed.

- Source: [main at `b08045acc1e982dd9424c1d8c91b0badd64744e8`](https://github.com/egohygiene/mantle/tree/b08045acc1e982dd9424c1d8c91b0badd64744e8).
- Candidate branch: `docs/engineering-readiness-audit-2026-10-28`; actual review reference is in [CONTINUITY.md](../CONTINUITY.md).
- Complete roadmap: [new parent #45](https://github.com/egohygiene/mantle/issues/45). Companion: [Realm #25](https://github.com/egohygiene/realm/issues/25).
- Report status: **complete audit workflow; partial runtime/platform validation**.
- Before audit: **3 open issues, 0 open PRs**. Added **3 focused follow-ups** and one coordination parent. Current work: **6 issues = 3 ready + 3 gated**, excluding the parent and PRs.
- Inspectable evidence: [validation, coverage, preservation, and hierarchy JSON](evidence/mantle-engineering-readiness-20261028T064323Z.json).

## Scope, authority, and discovery

The authorized work is inspection, proportionate checks, issue/roadmap reconciliation, and audit/continuity artifacts in a draft PR. Product changes, CI repairs, dependency upgrades, merges, releases, deployment, history rewriting, and creative changes are excluded.

The source has **455 tracked files**, a sourceable cross-shell runtime, public dispatcher and flat bin utilities, private installer/command backends, Python storage/archive/HLS implementations, typed profile/config/command metadata, layered tests, packaging scripts, provenance, generated Identity assets, and original optional artwork. No repository-local AGENTS.md or SECURITY.md exists. Existing CONTINUITY.md is an informal Markdown checkpoint, not an adopted machine-readable fleet contract.

Canonical sources inspected:

| Guidance | Immutable source / disposition |
| --- | --- |
| Aether auditor specification | `dc8a16851f452763ef4f7fbe4bf057d4500b1921`, approved v2.0.0 |
| Audit / issue-authoring / continuity skills | Same revision; draft 1.1.0 / experimental 1.2.0 / draft 1.1.0 |
| Hygiene continuity policy | `aa6a5e25ea3ef80e4dcc15570a1ea166b9f4af3d`, proposed 1.0.0-alpha.1, observe |
| Organization title/label guidance | `ac2e4035173ed252d71d6655e723964ef93684df`, title 1.0.1, explicit adoption |

These are provenance for the procedure, not a claim that every draft standard is adopted here. No primary `type:*` provider labels were provisioned. New issues use the canonical title style plus verified existing labels, without claiming complete title/label conformance. Organization AGENTS.md explicitly does not auto-inherit.

Discovery covered README/architecture/system/product documents, decisions, provenance and installer assurance, continuity, Taskfile, all workflows, dependency locks, runtime/installer/CLI and Python source, tests, guides, the existing August audit, every open issue body, relevant completed feature history, and native hosted job evidence. No open issue had discussion to reconcile at the initial snapshot.

## Current behavior versus drafts and releases

| State | Evidence and implication |
| --- | --- |
| Implemented source | Bash/Zsh source entrypoint and native Fish runtime; profiles/literal config; CLI catalog/introspection; quiet opt-in presentation; installation/update/rollback/disable/uninstall; installer assurance; storage/archive/HLS commands. |
| Source ownership | ARCHITECTURE.md and PROVENANCE.md separate reusable Mantle behavior from Realm environment construction. Root architecture/roadmap remain draft documents; implementation evidence determines availability. |
| Local execution | Unit/integration layers completed inside the combined run; independent contract/static/install smoke completed. Bin tests found two host-permission-dependent failures. The full combined run did not complete successfully. |
| Native hosted evidence | At the exact source, Linux and static jobs passed; macOS failed its startup-timeout integration fixture. Identity verification passed. |
| Packaging source | Deterministic tarball and release-lifecycle tooling exist, with source/fixture tests. Tag-triggered signing/attestation/publication workflow exists. |
| Released capability | **No GitHub Release exists.** Locally packaged/tested source is not an available signed published release. #26 remains the owner. |
| Optional designs | Flow shortcuts and ADR-history adoption remain gated. No new feature expansion is needed for a usable existing runtime. |

Closed #17/#18/#19/#32/#33/#34 describe delivered source work; their closure does not establish publication. This audit does not reopen, replace, or declare the original history invalid. #20's October 17 revision now selects **Flow**, so old ROADMAP references to direct Aniflow integration are stale operational guidance.

## Findings and coverage

| Finding | Classification | Severity / confidence | Coverage |
| --- | --- | --- | --- |
| AUDIT-001 — native macOS timeout fixture fails | Confirmed defect in validation | Medium / high | Gap → new [#42](https://github.com/egohygiene/mantle/issues/42) |
| AUDIT-002 — publisher overwrites assets and lacks the requested reviewed manual boundary | Confirmed acceptance gap | Medium / high | Existing [#26](https://github.com/egohygiene/mantle/issues/26), dated evidence added |
| AUDIT-003 — directly acquired CI tools have mutable/unverified inputs | Maintainability risk | Medium / high | Gap → new [#43](https://github.com/egohygiene/mantle/issues/43) |
| AUDIT-004 — sysinfo tests rely on host networking permissions | Confirmed test gap | Low / high | Gap → new [#44](https://github.com/egohygiene/mantle/issues/44) |
| AUDIT-005 — current handoff/sequence references completed work | Documentation gap | Low / high | Candidate audit/ROADMAP/continuity artifacts and parent #45 |
| AUDIT-006 — shared private-reporting guidance is unfinished | Documentation gap | Low / high | Existing organization [#24](https://github.com/egohygiene/.github/issues/24); no duplicate local policy |

### AUDIT-001 — the latest default-branch macOS job is red

**Status:** confirmed native validation failure; user-visible runtime failure is unproven. **Area:** startup/PTY tests. **Effort:** medium. **Impact:** medium for supported-platform confidence.

[Run 39167126727](https://github.com/egohygiene/mantle/actions/runs/39167126727), [macOS job 117792294690](https://github.com/egohygiene/mantle/actions/runs/39167126727/job/117792294690), failed integration case 231: “startup bounds a slow display command and returns to the caller.” The traceback ends at os.killpg in stop_fixture_group (`tests/fixtures/startup/run-pty.py:17`) with PermissionError. The current fixture already attempts to distinguish zombie-only groups, so blindly suppressing all permission errors is not an adequate fix.

Linux and static passed at the same revision; the preceding PR run also passed. Frequency and exact Darwin race are unknown. Later macOS contract/bin/install-smoke steps were skipped after failure.

**Recommendation:** #42 diagnoses and repairs one bounded fixture/runtime interaction, preserving deadlines, descendant cleanup, and terminal recovery. **Validation:** repeated native macOS startup cases, full integration, remaining skipped layers, plus Linux regressions. Local Linux success is not native macOS reproduction. No artwork change is needed.

### AUDIT-002 — release immutability is an existing unfulfilled criterion

**Status:** confirmed source/acceptance mismatch. **Area:** release publication. **Effort:** medium. **Impact:** high for trustworthy distribution.

`.github/workflows/release.yml:91` uses `gh release upload --clobber` when a release exists. The workflow is triggered by v* tag pushes, while #26 calls for a reviewed manual release path that cannot overwrite an immutable release. `tests/contract/release-workflow.bats` currently requires the clobber string; a passing grep contract does not prove immutability. Root CHANGELOG.md, the requested release declaration/semantic policy, and release Task handoffs are absent.

**Coverage:** #26 fully owns these outcomes; an additive note records the exact conflict rather than creating duplicate tickets or changing its acceptance criteria. **Recommendation/validation:** preserve immutable version/archive identity, distinguish retry from byte replacement, test existing-identical versus differing assets and denied publication, and verify the chosen manual authority boundary.

Current-v1 Aether/Hygiene/Relay source foundations are closed. Egolint #29 fixture/dogfood closeout is still open; compatible usable inputs and actual publication remain separate evidence. Successor Hygiene #65 work is a distinct lane, not a reason to halt bounded current-v1 preparation. **Gate:** green candidate, compatible verification, and explicit maintainer publication approval. Nothing is released by this audit.

### AUDIT-003 — action pins do not pin tools inside run steps

**Status:** confirmed acquisition gap; no compromised dependency is asserted. **Area:** CI supply-chain maintenance. **Effort:** small/medium. **Impact:** medium.

`.github/workflows/test.yml:33` downloads shfmt 3.8.0 without a recorded checksum, clones shdoc's moving default branch, and executes Bats tag archives without digest verification in Linux/macOS jobs. The Actions themselves are SHA-pinned.

**Recommendation:** #43 pins shdoc's full commit and verifies directly acquired artifacts before execution, using an existing shared mechanism if it satisfies this narrow outcome. **Validation:** controlled correct/wrong/missing-input checks and affected native jobs. Host-managed apt/Homebrew packages retain their declared OS boundary; no universal package lock or new CI framework is required. This can start without Flow or ADR adoption.

### AUDIT-004 — opt-in network diagnostics are not hermetically tested

**Status:** confirmed environment-dependent test gap. **Area:** bin CLI validation. **Effort:** small. **Impact:** medium for reproducible local checks.

The independent bin run executed **426 cases: 416 passed, 8 skipped, 2 failed**. Only sysinfo's include-network and all success cases failed. Those tests execute real host network tools; a tool found in this restricted Linux environment cannot inspect host networking. Native hosted Linux passed at the same source. This evidence does not establish an ordinary-host sysinfo runtime defect.

**Recommendation:** #44 uses literal controlled network-tool fixtures for ordinary tests, covers success/missing/denied states, and keeps any native canary explicit. Change command behavior only if a contract defect is established. **Validation:** focused sysinfo and complete bin layers under restricted/native environments. Raw hostnames, interfaces, sockets, and environment output are excluded from committed evidence.

### AUDIT-005 — completed startup work still appears current

**Status:** confirmed; repair proposed only in handoff artifacts. **Area:** documentation. **Effort:** small. **Impact:** medium.

CONTINUITY.md points at #34 and a feature branch/PR to review, despite the implemented feature and subsequent migrations already being on main. ROADMAP.md's current eight-issue sequence includes closed features and calls #20 an Aniflow adapter after its Flow revision. Older measured counts and shfmt debt must not be treated as current results.

This candidate replaces stale operational checkpoint prose and adds a dated roadmap pointer while preserving historical strategy/snapshots and the original August audit. It does not migrate ADR history or force the draft Aether schema. **Validation:** live issue/main/PR comparisons, exact checks, local links and diff scope. #45 holds the complete current ledger.

### AUDIT-006 — reporting/support defaults belong to existing organization work

**Status:** confirmed absence in inspected root/.github/docs default locations. **Area:** contributor/security intake. **Effort:** small at the shared owner. **Impact:** medium for discoverability.

Neither repository nor the inspected organization defaults has SECURITY.md. Organization #24 explicitly owns security/support default applicability and forbids promising an unestablished channel. Consume that decision when available; do not fabricate contacts, response guarantees, or a new policy. No sensitive vulnerability details were confirmed or placed in public issues/reports. This policy gap is not a comic-authoring blocker.

## Validation performed and its limits

| Check | Observed result | Evidence class |
| --- | --- | --- |
| `./tests/run.sh --local all` | Exit 1/incomplete. Unit: 71 pass/2 skip. Integration: 339 pass/22 skip. Contract stopped after 66 of 75 reported passes without a final summary. | Executed source; incomplete combined run, unexplained termination |
| `./tests/run.sh contract` | Exit 0; 75 pass, 0 fail/skip | Independent rerun because combined evidence was incomplete |
| `./tests/run.sh bin` | Exit 1; 416 pass, 8 skip, 2 sysinfo failures | Executed source; mostly controlled fixtures; two real host diagnostic dependencies |
| `./tests/run.sh --local static` | Exit 0; 7 passed groups, 2 skipped groups | Bash/POSIX/Zsh syntax, ShellCheck and shfmt executed; Fish and shdoc absent |
| `/bin/bash ./tests/smoke/install.sh` | Exit 0 | Real temporary-prefix copy/reinstall/dispatch/status/uninstall, no user hooks |
| `python3 tests/validate_fastfetch.py` | Exit 0 | Offline structural/presentation validation, not real Fastfetch rendering |
| Original PNG digest | Matches documented original SHA-256 | Actual file hash |
| Hosted Test Suite at source SHA | Linux/static pass; macOS integration failure | Existing remote evidence, not local execution |
| Hosted Identity at source SHA | Pass | Existing remote evidence; no assets regenerated |

The distinct Bats layers exposed **935 planned cases**: unit 73, integration 361, contract 75, bin 426. Across the completed individual layer evidence there were **901 passes, 32 explicit skips, 2 failures**. This aggregate is not a successful full-run claim. No cause is assigned to the first combined-run interruption; the independent contract rerun passed.

Environment: Ubuntu 24.04.3 LTS x86_64, Bash 5.2.21, Python 3.12.14, Zsh available, Bats 1.11.0 at `5da66876b8b619235aee1eb3e54954eaca88059b`, ShellCheck 0.10.0, shfmt 3.8.0. Temporary external tools are audit prerequisites, not dependency updates. Direct test-tool downloads in this audit were fetched from official upstream HTTPS and hashed; only Task was independently matched to a repository-pinned digest. That limitation is not upgraded to authenticated tool provenance.

Unavailable locally: native macOS/ARM64/Windows, Fish, shdoc, native Fastfetch, Ruby/Gem, Docker, signature/publication services. Strict all was not run. Native HLS tests inside integration used generated media and loopback servers; installer/privileged/external-service tests use controlled stubs and do not establish real upstream installation or every legacy utility's operational safety.

No release, tag, registry write, real privileged operation, broad vulnerability scan, production/private-media test, user startup-file edit, or creative-material mutation was performed. Raw network/environment output is intentionally not committed.

## Strengths, provenance, and historical reconciliation

The architecture and layer registry distinguish shell activation, child-process CLI dispatch, installation, configuration-as-data, and platform adapters. Startup stays quiet/offline by default. Tool installation remains explicit, with version/assurance metadata and external licenses clearly separated from Mantle's MIT adapter code.

Storage/archive source uses explicit filesystem boundaries, safe member selection, owned temporary state, and no-overwrite publication. HLS has separate request/credential/partial-output boundaries and synthetic tests. Local test success is scoped to those fixtures, not generalized to every real input.

PROVENANCE.md records the immutable Empathy source, source blob identities, first-party MIT notices, and generated-material boundaries. The original Incompris PNG remains unchanged at:

`ed15d8fe05cf62691571130c19e21b2ba35f1da193628f34a68cd0da835aff80`

Its source record and optional text fallback remain intact. Identity inputs, generated Brand Kit, artwork, and creative intent were not regenerated, renamed, moved, or relicensed.

The [2026-08-06 audit](mantle-holistic-polish-20260806T124442Z.md) remains immutable:

| Historical findings | Current disposition |
| --- | --- |
| AUDIT-001 / 011 — formatting and discovery | Apparently resolved for current inspected static scope; local shfmt passed |
| AUDIT-002 / 008 — installer tests and rollback | Apparently resolved in source/fixtures plus successful temporary-prefix smoke |
| AUDIT-003 — version source | Changed: VERSION and release packaging now exist; actual published release still absent |
| AUDIT-004 — contribution guidance | Apparently resolved: CONTRIBUTING/ARCHITECTURE/PROVENANCE and documentation contracts exist |
| AUDIT-005 / 010 — release system | Partially resolved: packaging/signing workflow exists; #26 still owns changelog/manual/immutable release completion |
| AUDIT-006 — macOS startup | Changed: native jobs now exist; current failure is separately evidenced in #42 |
| AUDIT-007 — Fish root wiring | Documented intentional native-entrypoint boundary; Fish not executed locally in this audit |
| AUDIT-009 / 014 — environment diff | Current source/tests implement bounded behavior; no new runtime defect established |
| AUDIT-012 — Windows | Explicit experimental/limited direction; native Windows evidence still unavailable |
| AUDIT-013 — shdoc coverage | Unable to verify locally; shdoc absent; current hosted static job passed |

## Complete execution ledger and finite boundary

An asterisk marks an identified full-outcome dependency or approval gate. Preparation may still start; gate explanations live in the owning issues. All **6 open local work issues** appear once here; #45 and PRs are excluded.

| Order | Work | Full outcome | Lane |
| --- | --- | --- | --- |
| 1 | [#42](https://github.com/egohygiene/mantle/issues/42) — Fix and prove native macOS startup cleanup | Ready | core |
| 2 | [#44](https://github.com/egohygiene/mantle/issues/44) — Make sysinfo network tests hermetic | Ready | core |
| 3 | [#43](https://github.com/egohygiene/mantle/issues/43) — Pin and verify CI validation tools | Ready | core |
| 4 | [#26](https://github.com/egohygiene/mantle/issues/26) — Finish the portable immutable release boundary | Gated * | distribution |
| 5 | [#20](https://github.com/egohygiene/mantle/issues/20) — Add optional Flow shortcuts after publication | Gated * | optional |
| 6 | [#31](https://github.com/egohygiene/mantle/issues/31) — Backfill ADR history after shared adoption is ready | Gated * | optional |

Native GitHub sub-issue reads verified all six under #45. No competing suitable all-work parent existed: #26 is the release outcome and #31 is ADR adoption, so neither was expanded into an unrelated tracker.

**Next checkpoint:** #42, one diagnosis/fix PR with repeated native macOS proof, then #44/#43 as focused independent changes. The first-version engineering boundary is the existing runtime/installer/CLI scope with credible supported-platform validation, followed by #26's reviewed immutable release preparation. Actual publication remains separately approved; a first clean consumer must verify version/checksum/signature/provenance and recovery.

Stop expanding there. Flow presets, ADR-history migration, package-manager expansion, a larger Realm image, local AI, dashboards, and new shell ergonomics are optional. Drawing and writing can already proceed without those integrations. No new design decision is required here; the overlapping Realm UBI/runtime ownership choice is recorded in Realm #45, with Mantle reuse recommended.

All original open issue titles, labels, bodies, assignments, states, and acceptance criteria were preserved. Dated notes add evidence/gates. Candidate scope is audit/evidence, a dated ROADMAP pointer, and current continuity; no implementation or creative content changes. ADR not required: the audit recommends execution without ratifying a new architecture or migrating decision history.
