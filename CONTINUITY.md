# Mantle continuity

## Current checkpoint

- Objective: choose the next bounded checkpoint after the engineering audit and two completed fixes.
- Roadmap: https://github.com/egohygiene/mantle/issues/45.
- Recommended next work: #43, CI-tool acquisition pins; implementation has not started.
- Current merged-code baseline: `1d24af8c0833637a457d86735d8944790dc612de` on `main`.
- #42 completed through PR #47; merge `ae3cb576f9310fe1ff04acc02c35ae13663be256`.
- #44 completed through PR #48; merge is the current baseline above.
- Audit delivery branch: `docs/engineering-readiness-audit-2026-10-28`.
- Audit delivery PR: https://github.com/egohygiene/mantle/pull/46; verify its live merge state and exact head.
- Four open work issues remain: #43 ready; #26/#20/#31 have full-outcome gates. Parent and PRs excluded.

## Audit and source authority

The [dated audit](audits/mantle-engineering-readiness-20261028T064323Z.md),
[JSON evidence](audits/evidence/mantle-engineering-readiness-20261028T064323Z.json),
and native-hierarchy screenshot retain their original bytes and audited source
`b08045acc1e982dd9424c1d8c91b0badd64744e8`. Their original six-issue inventory,
failed baseline checks and first #42 recommendation describe that snapshot.
They do not supersede the two subsequently merged fixes or current issue state.

The audit PR integrates the merged code baseline without rewriting history,
resolves its older continuity snapshot, and updates only the current ROADMAP
pointer. Its diff against current main remains documentation/evidence only.
No repository-local AGENTS.md or adopted machine-readable continuity contract
was found. Proposed or draft fleet guidance does not become adopted policy.

## Current validation and limits — 2026-10-28

PR #48 head `f148d59f6922c843c1054c1cb28c9f144b83d35a` established the code
baseline: full local ./tests/run.sh --local exited 0 with 912 Bats passes /
33 skips / 0 failures; local static passed 7 groups with Fish/shdoc unavailable.
Profile/catalog validation and temporary-prefix install smoke passed.

[Native CI](https://github.com/egohygiene/mantle/actions/runs/40714208738)
passed Linux/macOS unit, integration, contract, CLI and install-smoke checks,
plus strict static validation. Identity verification passed. All 15 sysinfo
cases passed on both hosts; macOS 15.7.9 ARM64 used stock Bash 3.2.57 and Python
3.14.7. Five startup repetitions remained green. #42's original native repair
proof is retained in Actions run 40705846962.

The audit integration changes no executable code. Its local artifact/contract
checks and exact-head hosted results are recorded in PR #46. Check those live
results before merging. Native platform jobs execute controlled sysinfo inputs;
real host network inventory is not exercised. Optional Fish, HLS, Fastfetch,
platform and upstream-tool omissions remain explicit in the relevant job logs.
Fixtures do not establish real upstream installs, signing or publication.

## Next work and finite boundary

#43 is the remaining ready source-quality issue. #26 owns changelog/declaration,
semantic policy, Task handoffs and a reviewed non-overwriting manual release
path; compatible producer evidence and separate publication approval remain
gates. #20 waits for a supported published Flow CLI/preset interface. #31 keeps
its explicit shared-ADR-system scheduling gate and historical-authority rules.

Keep the next chosen checkpoint small; optional Flow/ADR work does not block
drawing or writing.

## Preservation and resume

Recheck main, open issues/PRs and live checks before acting. A merged PR does
not establish release publication or deployment. Preserve existing issue scopes,
acceptance criteria, labels, history and native parent relationships.
The original Incompris PNG remains SHA-256
`ed15d8fe05cf62691571130c19e21b2ba35f1da193628f34a68cd0da835aff80`.
Generated Identity assets, artwork and creative content are unchanged.

ADR not required: this reconciliation records execution status and preserves
an existing audit; it introduces no architecture or historical ADR disposition.
