# Mantle continuity

## Current checkpoint

- Work: [#44](https://github.com/egohygiene/mantle/issues/44), isolate sysinfo diagnostics from host permissions.
- Base: `ae3cb576f9310fe1ff04acc02c35ae13663be256` on `main`.
- Branch: `fix/sysinfo-network-tests-44`.
- PR: https://github.com/egohygiene/mantle/pull/48 (verify its live head and review state).
- Roadmap: https://github.com/egohygiene/mantle/issues/45.
- Implementation candidate: `2d090d26bd87d3e4d7094db55bf725be12c0531c`; this handoff is the only later file change.
- PR #47 merged at the base above; #42 is closed. Its final native proof is in Actions run 40705846962.
- Audit artifacts remain in separate draft PR #46; preserve this newer handoff when reconciling that candidate.

## Scope and behavior

The real sysinfo CLI runs against a private test PATH containing Bash,
formatting utilities, and controlled diagnostic stubs. Hostname, time, disk,
addresses, sockets, and supplied environment examples are synthetic. Available
host network tools cannot fill a missing fixture dependency. Bats keeps its
normal PATH; only the CLI receives the restricted path and clean environment.

Fifteen cases cover Linux/Darwin selection and formatting, alternate tools,
unavailable tools, permission-denied commands, exit-status preservation, and
opt-in network/environment disclosure. Installed-tool failure remains nonzero
and can leave partial output; missing optional tools can yield unavailable
sections with status 0. The help now documents those existing behaviors.
All implementation outside the usage text is byte-identical to the base.

Changed surfaces: bin/sysinfo help, sysinfo.bats, coverage-map metadata,
the test guide, and this handoff. Runtime behavior, Brand Kit, artwork, and
creative content are unchanged. The Incompris PNG remains SHA-256
`ed15d8fe05cf62691571130c19e21b2ba35f1da193628f34a68cd0da835aff80`.

## Local validation — 2026-10-28

Linux x86_64, Bash 5.2.21, Python 3.12.14, Bats 1.11.0:

- Baseline focused sysinfo: 6 passed / 2 failed, reproducing #44.
- Candidate focused sysinfo: 15 passed, no skips or failures.
- Complete ./tests/run.sh --local: exit 0; 11 groups passed / 2 optional static skips.
- Bats layers: unit 71 passed / 2 skipped; integration 341/23; contract 75/0;
  bin 425/8. Total 912 passed / 33 skipped / 0 failed.
- Independent bin: 425 passed / 8 optional skips / 0 failed.
- Local static: 7 groups passed / 2 unavailable-tool skips (Fish and shdoc).
- Profiles (6), command catalog (90), temporary-prefix install smoke,
  shfmt and whitespace checks passed.

## Hosted evidence and limits

PR #48 records the Linux/macOS, strict static, and Identity jobs for its exact
head. Verify those live checks before merge. Native jobs run the controlled
sysinfo cases under real platform shell interpreters; this is not evidence of
real-host network inspection. No native network inspection canary is retained.
Local missing-tool skips do not prove Fish/shdoc behavior. Optional HLS,
Fastfetch, platform and upstream-tool omissions remain explicit in job logs.
No raw host network inventory, environment values, or credentials are evidence.

## Resume and boundary

Review PR #48 after its required native checks; #44 stays open until review and
merge. Then take #43 as a separate checkpoint. The five remaining work issues
and #26/#20/#31 gates are recorded in #45. Release publication and optional
Flow/ADR completion do not block drawing or writing.

ADR not required: test isolation and documentation of existing CLI status
behavior do not change architecture. No merge, tag, release, deployment,
history rewrite, shell preference change, or creative-material change is
implied by this snapshot.
