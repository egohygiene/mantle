# Mantle continuity

## Current checkpoint

- Objective: review issue #26's current-v1 portable immutable release source candidate.
- Roadmap: https://github.com/egohygiene/mantle/issues/45.
- Independent base: `9bdb5fb43dc803420371e1b8cfc1ce8628a9ed3a` on `main`, including completed #43 through merged PR #49.
- Candidate: `fix/26-portable-release-boundary`; draft PR https://github.com/egohygiene/mantle/pull/50, prepared for source review.
- Live state checked 2026-10-30: #26 and draft PR #50 remain open. No merge, tag, publication or issue closure is claimed.

## Material changes and ownership

`.egohygiene/release.json` selects one `git-tag` authority, stable immutable tags,
reviewed manual publication and mandatory future evidence. `CHANGELOG.md` starts
with Unreleased rather than invented release history. AGENTS points to these
facts and the release guide; no machine continuity or fleet adoption is implied.

The manual producer binds explicit approval, current-main identity, a reviewed
changelog and successful exact-source manual Linux/macOS/static qualification.
It retains genuine Cosign sign/verify and GitHub attestation steps, then delegates
immutable publication to published Relay v1.5.0 at
`1eada5142f7fc7da7862f335589e3b8f5884ffaf`. Test Suite gains only a manual trigger
for later qualification; its existing jobs and automatic triggers remain.

The packager atomically refuses existing archives and emits one generated inert
receipt. Copy installation retains optional receipts, clears an old receipt on
development update and restores it with transaction rollback. Receipts never
select versions, prove authentication, execute shell or become mandatory for
development/doctor. Source `VERSION` stays `0.1.0-dev`; startup needs no Python.

On-demand preparation prints reviewable plans/changelog patches, checks committed
local source, and records complete bundle checksums, source-file SPDX inventory
and honest signature availability. Relay's generic file validation does not prove
cryptographic verification. The guide explains outer `binary-vX.Y.Z` and nested
Mantle archives, semantic compatibility, independent authentication and rollback.

## Actual validation and independent review

- The unfixed-source checkpoint proved five expected regression failures while four clean/invalid-version controls passed.
- Four focused Bats suites pass: release-workflow (4), release-package (5), release-boundary (8) and release-control (7), with additional controlled subcases.
- `./tests/run.sh --strict` passes on Linux AMD64 after review fixes: 961 Bats passes, 14 explicit optional platform/tool skips, zero failures; all 13 runner groups pass. All nine static groups pass.
- `./bin/mantle profiles validate` validates six profiles; `./bin/mantle catalog validate` validates 90 commands. Isolated install smoke and offline Fastfetch checks pass.
- Exact selected Aether Draft202012Validator, Python 3.9 grammar, workflow YAML, 27 embedded Bash-step syntax checks and whitespace checks pass.
- Independent producer, Task/installer and data-boundary reviews found no remaining source blocker. Review repairs reject contradictory job status, boolean job IDs and null run/job collections; integer-ID positives and controlled nonzero/no-traceback negatives pass. These seams do not claim GitHub naturally emits those malformed records.
- A clean implementation-head source archive was byte-reproducible: 551 members, 469 regular files. Its actual unpacked install lifecycle passed. Complete unsigned bundle mechanics pass the exact published Relay v1.5 binary validator; signature and attestation remain explicitly unavailable. The source-file inventory passes the independent SPDX 2.3 schema.
- The final clean-head artifact and remote verification receipt is retained in draft PR #50; package inventory alone is never treated as package-build or publication evidence.

## Exact native consumer result and limitations

Actual EgoLint #29 candidate `8b77103e8f96b430d2a8b6e778e297a0c915a8ab` reports
release `compliant`, all seven checks passed/complete, the release tool passed,
and zero release findings in aggregate JSON and SARIF. This is offline static
source conformance; external publication remains `not_verified`.

The complete native process exits 1: its separate portability pack reports 220
findings. Identity/path/message/severity comparison preserves all 218 baseline
findings (185 mode, 25 command, six workflow-shell, two home-path). The only two
additions flag the new Bats files' intentional non-executable 100644 source role,
consistent with existing Bats files. No modes or unrelated rules were weakened
to manufacture a repository-wide green result.

## Next recovery action

Review draft PR #50 with its exact remote head and source evidence after the
owning EgoLint #68/#69/#29 chain. Reconcile any newer continuity edit by evidence.
After source acceptance, separately authorize exact merged-source Linux/macOS
qualification, actual signing/attestation and publication. Do not execute release
Task publication commands or dispatch workflows as part of this source review.

## Dependencies, gates and authority

Current-v1 selections remain Aether
`8a2a3d08f3aa9da3847bd5277843506ab855192e` and Hygiene
`28f9d6c7519d820644572634ba4476614f418d83`; neither owner has published releases,
and Hygiene remains proposed. Successor Hygiene #65 and optional registries are
not silently adopted. Relay's published profile has no `release-name` input.

EgoLint #29 draft is https://github.com/egohygiene/egolint/pull/111. Local candidate
qualification does not establish released producer conformance or maintainer
acceptance. Full Mantle acceptance retains compatible accepted producer evidence,
hosted/native supported-platform qualification, real signing/attestation and
separate publication approval. Local unsigned bundles prove mechanics only.
No hosted workflow, real release Task, signing operation, tag or publication was
executed during this checkpoint; native macOS/Windows qualification is deferred.

## Preservation and update protocol

Preserve Bash 3.2, native Zsh/Fish, authored/Identity assets and historical audit
bytes. The Incompris PNG remains SHA-256
`ed15d8fe05cf62691571130c19e21b2ba35f1da193628f34a68cd0da835aff80`.
Keep this prose handoff, privacy boundaries and one concrete next action. Exclude
credentials, environment values, private paths and unrestricted logs from public
evidence. Refresh after domain validation and before future PR updates.

ADR not required: this implements the existing release convention without
changing product ownership, policy authority or historical decisions.
