# Mantle continuity

## Current checkpoint

- Objective: review issue #26's current-v1 portable immutable release source candidate.
- Roadmap: https://github.com/egohygiene/mantle/issues/45.
- Independent base: `9bdb5fb43dc803420371e1b8cfc1ce8628a9ed3a` on `main`, including completed #43 through merged PR #49.
- Candidate: `fix/26-portable-release-boundary`; draft PR https://github.com/egohygiene/mantle/pull/50, implementation checkpoint.
- Live state checked 2026-10-30: #26 and draft PR #50 remain open. No merge, tag, publication or issue closure is claimed.

## Material changes and ownership

`.egohygiene/release.json` selects one `git-tag` authority, exact stable tags,
reviewed manual publication and mandatory future evidence. `CHANGELOG.md` starts
with Unreleased rather than invented release history. AGENTS points to these
facts and the release guide; no machine continuity adoption is implied.

The manual release workflow requires explicit approval, current-main identity,
a reviewed changelog and successful exact-source manual Linux/macOS/static
qualification. It retains genuine Cosign sign/verify and GitHub attestation
steps, then delegates immutable publication to published Relay v1.5.0 at
`1eada5142f7fc7da7862f335589e3b8f5884ffaf`. Test Suite adds only a manual trigger
for that later qualification; its existing jobs and automatic triggers remain.

The source packager atomically refuses an existing final archive and emits one
generated inert receipt. Copy installation retains optional receipts, clears
an old receipt on development update, and restores it with transaction rollback.
Receipts never select versions, prove authentication, execute shell or become
a mandatory development/doctor dependency. Source `VERSION` stays `0.1.0-dev`.

The on-demand preparation helper prints plans/promotion patches, checks committed
local source and records complete bundle checksums, source-file SPDX inventory
and honest signature availability. Relay's generic file checks do not prove
cryptographic verification. The release guide explains outer `binary-vX.Y.Z`
and nested Mantle archives, semver compatibility, authentication and rollback.

## Actual validation and review

- The baseline regression checkpoint proved five expected failures while four clean/invalid-version controls passed.
- Four focused suites pass: release-workflow (4), release-package (5), release-boundary (8) and release-control (7), covering 24 Bats cases and additional controlled subcases.
- `./tests/run.sh --strict static` passes all nine groups with pinned tools. A transient formatting mismatch in the new Bats file was corrected before rerunning.
- Exact pinned Aether `Draft202012Validator`, Python 3.9 grammar, workflow YAML, 27 embedded Bash-step syntax checks and `git diff --check` pass.
- Independent review identified a contradictory in-progress/success qualification-job seam. The helper now requires completed successful exact-run/source jobs; positive and negative controls pass. Producer review and the full strict candidate run remain pending.
- Exact EgoLint #29 candidate `8b77103e8f96b430d2a8b6e778e297a0c915a8ab` reports release `compliant`, all seven checks passed, release tool passed and zero release findings in aggregate/SARIF. Full process exit is 1 from separate portability findings; no repository-wide green result is claimed.

A clean main baseline run with that same native producer independently reports
185 executable-mode, 25 command-portability, six workflow-shell and two home-path
findings. Candidate identity/path/message comparison after tracking the new
files remains part of final review; preserve intentional source/test file roles.

The merged base separately passed the full strict Linux AMD64 runner: 942 Bats
passes, 14 explicit optional platform/tool skips, zero failures and 13 passing
runner groups. That baseline does not qualify the candidate or native macOS.

## Next recovery action

Verify the remote branch and PR description. Complete independent producer
review, run the full strict candidate and isolated lifecycle checks, compare
native findings semantically with main, and refresh the final source handoff.
Do not run release Task publication commands or dispatch workflows during review.

## Dependencies, limits and authority

Current-v1 source selections are Aether
`8a2a3d08f3aa9da3847bd5277843506ab855192e` and Hygiene
`28f9d6c7519d820644572634ba4476614f418d83`; neither owner has published releases,
and Hygiene remains proposed. Do not adopt successor Hygiene #65 implicitly.

EgoLint #68/#69/#29 remains a separately reviewed chain; #29 draft is
https://github.com/egohygiene/egolint/pull/111. Local producer qualification does
not establish released conformance or maintainer acceptance. Mantle's full
outcome retains accepted compatible producer evidence, hosted/native supported
platform qualification, real signing/attestation and separate publication approval.
Local unsigned fixture bundles prove mechanics only. No hosted release or
qualification workflow, real release Task, tag or publication was executed.

## Preservation and update protocol

Preserve Bash 3.2, native Zsh/Fish, offline shell startup, authored/Identity assets
and historical audit bytes. The Incompris PNG remains SHA-256
`ed15d8fe05cf62691571130c19e21b2ba35f1da193628f34a68cd0da835aff80`.
Keep this prose handoff format, privacy boundaries and one concrete recovery
action. Exclude credentials, environment values, private paths and unrestricted
logs from public evidence. Refresh after domain validation and before PR updates.

ADR not required: this implements the existing release convention without
changing product ownership, policy authority or historical decisions.
