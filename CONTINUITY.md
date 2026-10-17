# Mantle continuity

## Current checkpoint

- Work: issue #34, configurable cross-shell startup display.
- Base revision: `44a2c3dba4db19ae468856f3a11bb3b39f1817a2`.
- Branch: `feat/34-startup-display`.
- Scope: opt-in startup command, Bash/Zsh/Fish hooks, offline Fastfetch collectors,
  original Incompris artwork, configuration, and focused validation.
- Default startup remains quiet. Existing XDG Fastfetch profiles take precedence;
  optional display failures do not fail initialization.

## Source and ownership

The Incompris PNG is restored unchanged from Alan's original Mantle commit;
`assets/presentation/README.md` records its source and hash. It is optional shell
artwork; the governed Mantle repository Brand Kit is unchanged.

This change implements the existing issue and DECISIONS.md boundaries: source
startup files, retain a native Fish entrypoint, and avoid implicit network or
privileged startup behavior. It introduces no organization policy or ADR-history
migration; #31 retains its own adoption gate.

## Verification

Linux source and PTY verification on 2026-10-17:

- 33 feature cases passed: 23 startup and 10 collector/profile cases, including
  real Fastfetch 2.67.0. Bash, Zsh, and Fish 3.7 startup cases ran without skips.
- 69 unit, 55 contract, and 17 existing dispatcher/banner cases passed.
- Final full integration: 159/166 passed.
  The same seven entrypoint/installer/RubyGems cases fail in an unchanged base
  worktree (126/133 passed). One RubyGems case hardcodes a PATH excluding the
  extracted Fish executable. No new integration failures were observed.
- Whole-repository Bash/POSIX/Zsh/Fish syntax and ShellCheck passed. Existing
  shfmt debt remains; changed shell/test files pass the canonical formatter.
  shdoc is unavailable, so that optional check did not run.
- The complete pinned Fastfetch 2.67.0 JSON Schema passed with zero errors.
  Native PTYs verified clean section headers and both iTerm and Kitty-direct
  PNG paths within the three-second budget (0.58/0.66 seconds observed).
- A real Fastfetch check opened configuration and logo filenames containing
  shell metacharacters literally, without creating the substitution markers.
- Deadline cases verify descendant cleanup, foreground TTY ownership, and
  recovery of cursor visibility, styling, and autowrap after interruption.
- Copy and symlink install coverage verifies the bundled profile and artwork
  travel with the runtime. A packaged no-hook install is also exercised with
  real Fastfetch; the installer now includes the `config/` runtime payload.
  Development symlink prefixes retain their installation root only when their
  dispatcher is the same executable, preserving rejection of unrelated roots.

Canonical commands: `./tests/run.sh unit`, `./tests/run.sh contract`,
`./tests/run.sh integration`, `./tests/run.sh static`, and focused Bats runs of
`tests/integration/startup.bats` and `tests/integration/fastfetch.bats`.
Set `MANTLE_TEST_FASTFETCH_BINARY` to an installed Fastfetch 2.67.0 binary to
enable the optional native profile case. Linux checks and simulated protocol
selection do not establish a live macOS terminal visual trial.

## Resume

Review the #34 PR and its verification evidence before selecting #32. Recheck
the default branch and open PRs before resuming. The eight-issue sequence is in
ROADMAP.md; release and Aniflow qualification retain their separate upstream
evidence requirements. No local user startup files are changed by this PR.
