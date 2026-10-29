# Mantle continuity

## Current checkpoint

- Objective: review #43's bounded CI-tool acquisition checkpoint.
- Roadmap: https://github.com/egohygiene/mantle/issues/45.
- Implementation branch: `fix/43-verified-ci-tools`; source and local checks are ready for review.
- Current merged baseline: `e7dba68918141f96492c2e608c1bf053139d66ab` on `main`.
- #42 completed through PR #47; merge `ae3cb576f9310fe1ff04acc02c35ae13663be256`.
- #44 completed through PR #48; merge `1d24af8c0833637a457d86735d8944790dc612de`.
- Audit delivery PR #46 is merged at the current baseline; historical audit bytes are unchanged.
- Four open work issues remain until tracker reconciliation: #43 under review; #26/#20/#31 retain full-outcome gates. Parent and PRs excluded.

## CI acquisition checkpoint — 2026-10-29

#43 now has one reviewed CI tool lock, a setup helper targeting Bash 3.2
reusing the existing download/checksum libraries, and shared Test Suite/HLS
workflow handoffs. shdoc uses the existing reviewed full commit plus a file
digest; shfmt has platform-specific upstream digests; both native Bats jobs and
HLS use one declared version/archive/digest. Setup uses a writable owned prefix
without sudo and verifies before extraction, installation, or execution.
The refresh contract and host-managed prerequisite boundary are in
[the CI tool guide](docs/ci-tools.md).

Local evidence: all 53 focused Bats cases passed (11 CI acquisition, 21 runner,
5 architecture, 7 checksum and 9 download); no focused skips. The acquisition
cases include shasum fallback and a malformed second pin rejected before any
acquisition. Real Bats/shfmt/shdoc downloads matched the checked-in digests and
installed in a disposable Linux AMD64 prefix. The shdoc raw digest also matched
the selected Git source. Local static validation passed 7 groups with 2 explicit
skips: Fish and shdoc parsing (GNU Awk is absent). Strict static remains
unsatisfied for those prerequisites; the runner's strict/local behavior is
unchanged. Both modified workflows parsed and their 26 shell steps passed
Bash syntax checks. These checks do not represent the entire product suite.

The maintainer has deferred hosted Actions and `act` qualification to a later
sweep due to budget constraints. Native macOS/Bash 3.2 and other architecture
artifacts were not executed here. Simulated Darwin artifact selection is an
offline fixture, not native proof. Commits use `[skip ci]` to avoid automatic
hosted push/PR runs. No hosted pass, release, or consumer qualification is claimed.

## Audit and source authority

The [dated audit](audits/mantle-engineering-readiness-20261028T064323Z.md),
[JSON evidence](audits/evidence/mantle-engineering-readiness-20261028T064323Z.json),
and native-hierarchy screenshot retain their original bytes and audited source
`b08045acc1e982dd9424c1d8c91b0badd64744e8`. Their original six-issue inventory,
failed baseline checks and first #42 recommendation describe that snapshot.
They do not supersede the two subsequently merged fixes or current issue state.

The merged audit PR integrated the prior code baseline without rewriting
history, resolved its older continuity snapshot, and updated the ROADMAP pointer.
Its historical scope was documentation/evidence only; #43 is a separate change.
No repository-local AGENTS.md or adopted machine-readable continuity contract
was found. Proposed or draft fleet guidance does not become adopted policy.

## Prior validation and limits — 2026-10-28

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

The prior audit integration changed no executable code. Its local
artifact/contract checks and exact-head hosted results are recorded in merged
PR #46. Native platform jobs execute controlled sysinfo inputs;
real host network inventory is not exercised. Optional Fish, HLS, Fastfetch,
platform and upstream-tool omissions remain explicit in the relevant job logs.
Fixtures do not establish real upstream installs, signing or publication.

## Next work and finite boundary

#43's source-quality implementation is now under review, with deferred
native/hosted qualification explicit above. #26 owns changelog/declaration,
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
