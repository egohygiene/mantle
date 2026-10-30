# Mantle continuity

## Current checkpoint

- Objective: prepare the current-v1 portable immutable release boundary for issue #26.
- Roadmap: https://github.com/egohygiene/mantle/issues/45.
- Independent base: `9bdb5fb43dc803420371e1b8cfc1ce8628a9ed3a` on `main`.
- Candidate: `fix/26-portable-release-boundary`, regression stage; no PR reference yet.
- Live state checked 2026-10-30: #43 completed through merged PR #49; #26 remains open without comments. No matching release candidate PR existed before this branch.
- Main's earlier handoff still described #43 under review; the verified merge supersedes that snapshot.

## Current outcome and boundaries

Keep one `git-tag` release authority, exact immutable `vMAJOR.MINOR.PATCH` tags,
and the existing development `VERSION` and installer compatibility. Add the
root changelog/declaration, bounded Task handoffs, semantic policy and reviewed
manual release path. Publication must never overwrite existing release assets.

Consume current-v1 Aether `8a2a3d08f3aa9da3847bd5277843506ab855192e` and Hygiene
`28f9d6c7519d820644572634ba4476614f418d83`. Neither owner has a published release;
Hygiene's selected profile remains proposed. Compatible published Relay v1.5.0
is `1eada5142f7fc7da7862f335589e3b8f5884ffaf`, whose binary profile wraps a
Mantle source archive rather than publishing it directly. Do not promote the
successor Hygiene #65 lane or claim cryptographic evidence from file presence.

## Diagnosis and actual checks

The existing workflow publishes on tag pushes and explicitly uses `--clobber`;
its old contract test required that overwrite. The local packager also replaces
existing archives. Generated release metadata lacks the exact tag/archive and
Relay evidence identity, and copied installations discard that metadata.

Two focused native Bats suites now expose these gaps. Four positive controls
pass, while five regression cases fail as expected on unfixed source:

- `./tests/run.sh tests/contract/release-workflow.bats`: two pass, two expected failures for overwrite/manual-dispatch policy.
- `./tests/run.sh tests/integration/release-package.bats`: two pass, three expected failures for archive overwrite, receipt identity and installed receipt retention.
- Bats 1.11.0 and shfmt 3.8.0 are the repository-pinned tools. Edited Bats files were formatted; `git diff --check` passes.

The merged base separately passed six profile definitions, the 90-command
catalog and the full strict Linux AMD64 runner: 942 Bats passes, 14 explicit
optional platform/tool skips, zero failures, and 13 passing runner groups.
That baseline does not qualify the new candidate or native macOS.

## Next recovery action

Inspect this branch, remote head and draft PR state. Implement the required
manual, non-overwriting boundary, retain optional inert installation receipts,
then run focused regressions and applicable strict/source checks. Keep the
three remote regression/implementation/review checkpoints recoverable.

## Dependencies and parallel work

EgoLint current-v1 chain #68/#69/#29 is being prepared separately; the #29
source candidate is draft PR https://github.com/egohygiene/egolint/pull/111.
Its preparation does not establish maintainer acceptance or released producer
conformance. Full Mantle acceptance still needs compatible accepted producer
evidence, supported-platform qualification and separate publication approval.

No Mantle PR, tag, release, workflow dispatch or publication is claimed by this
checkpoint. The original artwork and historical audits remain unchanged.
The Incompris PNG remains SHA-256
`ed15d8fe05cf62691571130c19e21b2ba35f1da193628f34a68cd0da835aff80`.

## Preservation and update protocol

Preserve Bash 3.2, native Zsh/Fish, offline shell startup, authored assets,
installer-owned mutation boundaries and the existing prose handoff format.
Release receipts are inert context, never executable shell or authentication.
Exclude private paths, credentials, environment values and unrestricted logs
from public evidence. Update this snapshot after domain validation and before
PR handoffs, recording actual results, limits, source heads and one next action.

ADR not required: this implements the existing release-convention issue without
changing product ownership, policy authority or historical decisions.
