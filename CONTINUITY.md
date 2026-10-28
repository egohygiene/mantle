# Mantle continuity

## Current checkpoint

- Work: [#42](https://github.com/egohygiene/mantle/issues/42), startup PTY cleanup on macOS.
- Base: `b08045acc1e982dd9424c1d8c91b0badd64744e8` on `main`.
- Branch: `fix/startup-pty-cleanup-42`.
- PR: https://github.com/egohygiene/mantle/pull/47 (open and unmerged; verify live review state).
- Roadmap: https://github.com/egohygiene/mantle/issues/45.
- Initial hosted repair evidence: `7e99ed969a29edcc9dfee044ed256d18aff6f2a6`.
- Final candidate adds a stricter interruption test and this handoff; live checks are attached to PR #47.
- Audit report and complete six-issue inventory remain in separate draft PR #46.

## Scope and evidence

Only the test fixture, startup regressions, test guide, macOS repetition step,
and this handoff change. Mantle runtime, Brand Kit, and original artwork are
unchanged. The Incompris PNG retains SHA-256
`ed15d8fe05cf62691571130c19e21b2ba35f1da193628f34a68cd0da835aff80`.

The PTY helper used a nonblocking poll to reject a denied group signal while
the leader could still be exiting. On EPERM it now allows a bounded two-second
reap before inspecting group states. Live leaders, live inaccessible members,
and failed process-state inspection still fail. No product runtime defect is
claimed from the original fixture failure.

The deferred-poll regression failed before the repair and passed afterward.
Permission/error paths use explicit mocks. The Darwin test uses a real process,
zombie state, group signal, state inspection, and reap; only poll observation
order is controlled. It is not a measurement of the uncontrolled race rate.
Timeout/interruption tests inspect descendants and terminal recovery before
the fixture's own safety cleanup. The interruption test uses a 30-second runtime
deadline inside a four-second fixture budget, preventing deadline fallback
from substituting for signal handling.

## Validation — 2026-10-28

Local Linux x86_64, Bash 5.2.21, Python 3.12.14, Bats 1.11.0:

- Focused startup: 30 passed / 2 skipped (Darwin-only case and missing Fish).
- Independent integration: 341 passed / 23 skipped; contract: 75 passed.
- Bin: 416 passed / 8 skipped / 2 existing host-network failures, tracked by #44.
- Local static: 7 groups passed / 2 unavailable-tool skips (Fish and shdoc).
- Temporary-prefix install smoke, offline Fastfetch/artwork validation,
  Python syntax, workflow YAML structure, shfmt and whitespace passed.
- Combined local all exited 1 without its final summary after unit 71 passed /
  2 skipped and 98 integration passes / 12 skips. No full local green claim;
  the subsequent standalone integration and contract runs completed.

Hosted source validation:
https://github.com/egohygiene/mantle/actions/runs/40703912648

Linux passed unit 72/1 skip, integration 332/32 skips, contract 75, bin 422/4
skips, and install smoke. Strict static and Identity verification passed.
Native macOS 15.7.9 ARM64, stock Bash 3.2.57, Python 3.14.7 passed five
startup repetitions (31 passed / 1 Fish skip each), then unit 72/1 skip,
integration 313/51 skips, contract 75, bin 416/10 skips, and install smoke.
The final candidate retains native state evidence in TAP and tightens the
interruption budget; verify its current PR checks before merge. HLS media and
native Fastfetch skips remain explicit; fixtures do not prove real upstream
installs or interactive terminal artwork rendering.

## Resume and boundary

Recheck main, PR #47, its exact head and Actions evidence. Review this one repair
checkpoint before taking #44, then #43. Do not close #42 before its native
evidence and review are complete. The roadmap's finite first-version boundary
and release approval gate remain unchanged. #20 and #31 remain optional/gated.

The prior #34 feature is implemented and closed; it is no longer the active
handoff. ADR not required: this repairs the established test cleanup contract.
No merge, release, deployment, history rewrite, shell preference change, or
creative-material change is authorized by this continuity snapshot.
