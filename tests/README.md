# Mantle Test Suite

This directory contains Mantle's behavioral test suite, organized into unit,
integration, contract, and bin CLI layers.

---

## Required local tools

| Tool | Minimum version | Purpose |
|------|----------------|---------|
| [Bats Core](https://github.com/bats-core/bats-core) | 1.5.0 | Test runner |
| Bash | 3.2+ | Required shell |
| Zsh | any | Optional (tests skip if absent) |
| Fish | any | Optional (tests skip if absent) |
| Python | 3.9+ | Release-package integration tests |
| FFmpeg/ffprobe | HLS `seg_max_retry` support (FFmpeg 6.1+) | Optional local HLS media fixtures; required by dedicated HLS CI |
| `shellcheck` | any | Static analysis (optional locally, required in strict mode) |
| `shdoc` | any | Installer docstring parsing (optional locally, required in strict mode) |
| `shfmt` | 3.8.0 | Formatting check / write mode |

For the exact CI versions, use the [verified CI tool setup](../docs/ci-tools.md).
It installs reviewed Bats, shfmt, and Linux shdoc artifacts into an explicit
writable prefix after SHA-256 verification. On Linux:

```sh
MANTLE_CI_PREFIX="$(mktemp -d "/tmp/mantle-ci-local.XXXXXXXX")"
/bin/bash ./scripts/ci/setup-tools.sh --prefix "${MANTLE_CI_PREFIX}" bats shfmt shdoc
export PATH="${MANTLE_CI_PREFIX}/bin:${PATH}"
```

GNU Awk (`/usr/bin/gawk`) is required by the pinned shdoc script. Host package
manager dependencies remain host-managed; this setup does not lock OS packages.
On macOS, request `bats shfmt`; the native macOS CI job only requests Bats.

For a host-managed Bats installation instead:

```sh
# macOS
brew install bats-core

# npm (cross-platform)
npm install --global bats
```

The controlled acquisition fixtures run with
`./tests/run.sh tests/integration/ci-tools.bats`. See the setup guide for digest
provenance, update ownership, and the later native/hosted qualification boundary.

---

## Running the tests

### Run everything

```sh
./tests/run.sh --local
./tests/run.sh --strict
```

Local mode reports unavailable Zsh, Fish, ShellCheck, shdoc, and shfmt as explicit
skips. Strict mode requires each of those tools. Available-tool failures, failed
source discovery, empty suites, and failing Bats tests fail in both modes. Every
run prints passed, failed, and skipped validation-group counts; Bats reports
individual test results separately. The default remains local mode.
`MANTLE_VALIDATION_STRICT=1` selects strict mode unless `--local` overrides it.

### Run one layer only

```sh
./tests/run.sh unit
./tests/run.sh integration
./tests/run.sh contract
./tests/run.sh bin
./tests/run.sh static
./tests/run.sh format
```

### Run a single file

```sh
./tests/run.sh tests/unit/core/guards.bats
# or, using bats directly:
bats tests/integration/entrypoint.bats
bats tests/integration/install-root.bats
bats tests/integration/profiles.bats tests/integration/catalog.bats
bats tests/integration/hls-download.bats
bats tests/bin/generate-password.bats
```

`static` checks maintained shell sources with Bash/POSIX syntax validation,
optional Zsh and Fish syntax checks, ShellCheck, `shdoc` parsing for
`install.sh`, and `shfmt` in check mode.
`format` rewrites the maintained `bash`, `posix`, and `bats` file sets using the
canonical `.editorconfig` policy and intentionally skips `.shellrc` plus the
native Zsh runtime because `shfmt` does not support their syntax.

The optional root Taskfile preserves `task validate` (profile/catalog validation
then local static checks), `task test` (the complete local runner), and
`task doctor`/`task status`. `task lint`, `task docs`, and `task install:smoke`
select focused checks. `task check` adds the install smoke to local validation;
`task ci` runs the complete strict runner and install smoke.

The hermetic install smoke can also run directly:

```sh
/bin/bash ./tests/smoke/install.sh
```

It uses a temporary HOME and prefix, performs copy installation and a repeated
installation, checks the installed CLI and ownership status, then uninstalls.
It disables shell hooks and verifies that no startup files were created.
`python3 tests/validate_fastfetch.py` separately checks the bundled Fastfetch
configuration and current Incompris artwork offline; Fastfetch itself is optional.
Metadata can also be checked directly with `./bin/mantle profiles validate` and
`./bin/mantle catalog validate`. The profile/catalog integration tests exercise
clean shell startup, graph failures, inherited applicability, inventory drift,
and malformed metadata without executing cataloged utilities.

The HLS tests generate synthetic media and use loopback HTTP servers only. They
skip locally when the required media tools are unavailable. The dedicated
`.github/workflows/hls.yml` Linux/macOS jobs set `MANTLE_REQUIRE_HLS_TESTS=1`, so
missing dependencies or capabilities fail instead of silently skipping coverage.
Fixture request events retain route names and boolean request-shape facts only;
the workflow does not upload request or media artifacts.

### Startup process cleanup

`tests/integration/startup.bats` uses real PTYs and synthetic display commands.
The PTY helper stops the fixture's process group on completion or deadline.
If Darwin reports `EPERM`, it allows up to two seconds to reap an exiting
leader, then checks the group for live members. A still-running leader, live
inaccessible member, or failed state inspection remains a test failure.

The native Darwin case creates a real zombie-only group and verifies its
`EPERM` response. It deliberately defers the nonblocking `poll()` observation
to exercise the exit-ordering race; group signaling, process-state inspection,
and the bounded reap use native system calls. Other permission/error paths use
explicit mocks. Timeout and interruption cases check real descendant cleanup
and terminal recovery before the fixture's own safety cleanup runs.

The macOS job reports OS/architecture/Bash/Python versions and repeats the
startup file five times before running the normal validation layers. To repeat
the focused checks locally with the same interface:

```sh
for attempt in 1 2 3 4 5; do
  /bin/bash ./tests/run.sh tests/integration/startup.bats || exit "$?"
done
```

The Darwin process-state case skips on other systems; Linux results alone do
not establish macOS behavior. Optional Fish startup coverage still depends on
Fish being available.

### Run a single test by name

```sh
bats --filter "mantle_guard_has_command returns 0" tests/unit/core/guards.bats
bats --filter "generate-password --length 16" tests/bin/generate-password.bats
```

---

## Test suite architecture

```
tests/
├── bin/                    bin/ CLI behavioral tests (black-box)
│   ├── helpers/
│   │   ├── assertions.bash  Exit-status, output, and file assertions
│   │   ├── environment.bash Isolated HOME/XDG setup and run_bin helper
│   │   └── stubs.bash       Stub factories for external dependencies
│   ├── coverage-map.tsv    Machine-readable inventory of every bin/ command
│   ├── coverage-guard.bats Guard that enforces coverage-map completeness
│   ├── shared-contract.bats --help, --version, and unknown-option for all commands
│   └── <command>.bats      Per-command behavioral tests
├── contract/               Repository-layout and public-API contract tests
├── integration/            Integration tests for bin/mantle and shell bootstrap
├── test_helper/            Shared helpers for unit/integration/contract layers
│   ├── assertions.bash
│   ├── common.bash
│   ├── fixtures.bash
│   └── stubs.bash
└── unit/                   Unit tests for lib/ functions
```

---

## bin/ test layer

### How it works

Every test file in `tests/bin/` invokes commands from `bin/` as a user would,
using the `run_bin` helper from `helpers/environment.bash`. Each test:

- Calls `bin_test_setup` in `setup()` and `bin_test_teardown` in `teardown()`.
- Gets a freshly created `BIN_TEST_HOME` directory as an isolated `HOME`.
- Gets isolated `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME`,
  `XDG_STATE_HOME`, and `XDG_RUNTIME_DIR` inside that home.
- Gets a fresh `BIN_STUB_DIR` prepended to `PATH` for dependency stubs.
- Unsets developer credentials (`GH_TOKEN`, `GITHUB_TOKEN`, etc.).

External commands that would cause real mutations (Docker, apt, sudo, GitHub
API, network) are replaced with stubs from `helpers/stubs.bash`.

`sysinfo.bats` additionally gives the real CLI a private `PATH` containing only
Bash, formatting utilities, and controlled diagnostic stubs. Hostname, time,
disk, interface addresses, and sockets use synthetic values; optional host
diagnostics cannot be discovered through the developer's normal `PATH`.
The cases cover Linux and Darwin selection/formatting, fallback tools, missing
tools, denied commands, preserved failure statuses, and opt-in disclosure.
Missing optional tools produce unavailable sections with status 0; an installed
diagnostic that fails keeps its nonzero status and may leave partial output.
The Linux and macOS jobs execute these same controlled cases with native shell
interpreters. They do not inspect the real host's network; no native network
inspection canary is retained in the ordinary suite.

### Running a single command's tests

```sh
bats tests/bin/generate-password.bats
bats tests/bin/shell-banner.bats
```

### Coverage map

`tests/bin/coverage-map.tsv` is a tab-separated file with one row per `bin/`
command. Columns:

| Column | Description |
|--------|-------------|
| `command` | Executable name in `bin/` |
| `test_file` | Bats file (relative to `tests/bin/`) providing coverage |
| `categories` | Comma-separated behavior categories covered |
| `exemptions` | Behaviors not covered (or `none`) |
| `exemption_reason` | Justification for every exemption |

### Coverage guard

`tests/bin/coverage-guard.bats` enforces that:

1. Every regular executable in `bin/` has a coverage-map entry.
2. Every test file listed in the map exists on disk.
3. Every command in the map still exists in `bin/`.
4. Every non-`none` exemption has a non-empty justification.

The guard runs as part of `./tests/run.sh bin` and in CI. It fails when a new
`bin/` command is added without registering it.

### Adding tests for a new bin/ command

1. Add an entry to `tests/bin/coverage-map.tsv`:

   ```
   my-command	my-command.bats	help,version,unknown-option,core-behavior	none	none
   ```

2. Create `tests/bin/my-command.bats`:

   ```bash
   #!/usr/bin/env bats
   setup() {
       load 'helpers/environment'
       load 'helpers/assertions'
       load 'helpers/stubs'
       bin_test_setup
   }
   teardown() { bin_test_teardown; }

   @test "my-command --help exits 0" {
       run_bin my-command --help
       assert_success
       assert_output_contains "Usage"
   }
   ```

3. Run `bats tests/bin/coverage-guard.bats` to confirm the guard passes.

### Safety requirements

Tests never perform real:
- `sudo` or root-privileged changes.
- Package installs or removals.
- APT source modifications.
- Docker daemon mutations.
- GitHub / GCloud API mutations.
- Network downloads.
- SSH transfers.
- Clipboard writes to a developer display.
- Audio capture or display changes.

Dangerous operations are isolated behind stubs in `helpers/stubs.bash`.

---

## Isolation model

Every Bats test that interacts with the shell environment calls
`setup_isolated_home` from `test_helper/common.bash`. This function:

- Creates a temporary directory under `$TMPDIR` as a private `HOME`.
- Sets isolated XDG directories (`XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, etc.)
  inside that temp home.
- All files created during a test live inside that temp directory.
- `teardown_isolated_home` removes the directory after each test.

Shell subprocesses are launched with a minimal, clean environment:

```sh
env -i HOME="$TEST_HOME" MANTLE_ROOT="..." PATH="..." /bin/bash --noprofile --norc -c "..."
zsh --no-rcs -c "..."
```

This prevents your `.bashrc`, `.zshrc`, developer-machine tools, or personal
environment variables from influencing test results.

---

## Command stubs

`test_helper/stubs.bash` provides helpers for creating fake executables that
replace real tools during a test.

```bash
setup_stub_dir        # creates $STUB_DIR, prepends it to PATH
create_stub curl 0 "fake output"      # curl always succeeds
create_recording_stub git             # git records its arguments
stub_curl_success "response body"     # curl writes body to -o destination
```

`tests/bin/helpers/stubs.bash` provides domain-specific stubs for the bin/
test layer:

```bash
bin_test_setup             # sets up BIN_STUB_DIR and prepends to PATH
make_stub NAME [code [out]] # simple stub
make_recording_stub NAME    # stub that records argv to NAME.calls
stub_curl_success BODY      # curl writes body to -o file
stub_gh [code [out]]        # GitHub CLI stub
stub_docker [code]          # docker recording stub
stub_ffmpeg                 # ffmpeg recording stub
```

Stubs are isolated per-test: `bin_test_teardown` removes `$BIN_STUB_DIR`
after each test.

---

## Fixtures

Static test data lives in `tests/fixtures/`:

| Directory | Contents |
|-----------|---------|
| `archives/` | Pre-built `.tar.gz` and `.zip` archives |
| `checksums/` | SHA-256 and SHA-512 checksum files |
| `github/` | Mocked GitHub release API responses |
| `installers/` | Installer-specific fixture data |
| `repositories/` | Minimal Git repositories |

Helper functions in `test_helper/fixtures.bash` can generate fixtures
dynamically in `$TEST_HOME` when static files are not needed.

---

## Adding a unit test

1. Create or edit a file in `tests/unit/<layer>/`.
2. Load the standard helpers:

   ```bash
   setup() {
       load '../../test_helper/common'
       load '../../test_helper/assertions'
       setup_isolated_home
   }
   teardown() { teardown_isolated_home; }
   ```

3. Write a `@test` block that sources the library under test inside a clean
   subprocess.

---

## Adding an integration test

1. Create or edit a file in `tests/integration/`.
2. Tests here source `.shellrc` or invoke `bin/mantle` in a clean environment.
3. Avoid testing internal details — prefer the public interface.

---

## Adding an installer to the matrix

Every installer in `libexec/mantle/installers/` is validated automatically
by `tests/integration/installers.bats` (dynamic discovery, no hand-written
list). Deeper installer tests:

1. Add a `@test` block in `tests/integration/installers.bats` that calls
   `_mantle_install TOOL --dry-run`.
2. Stubs for network dependencies go in the test's `setup()` via
   `stub_curl_success` or similar.

---

## CI requirements and shells

| Job | OS | Shells tested |
|-----|----|---------------|
| `static` | Ubuntu | Bash (syntax + ShellCheck + shfmt) |
| `test-linux` | Ubuntu | Bash, Zsh, Fish |
| `test-macos` | macOS | Bash, Zsh |
| `hls` (dedicated HLS workflow) | Ubuntu 24.04, macOS | Stock Bash; external invocation from available Zsh/Fish |

The complete bin/ CLI catalog is gated on Linux. The macOS job covers Mantle's
portable shell runtime, installer, release lifecycle, and contracts; individual
utilities with Darwin support keep platform-specific tests in their own files.

Required shells (`bash`, `zsh`, `fish`) are installed in CI so required
coverage never silently passes through skips.

### Which local skips are acceptable

- `skip "zsh is not available on this system"` — acceptable locally if Zsh
  is not installed; CI always has Zsh.
- `skip "not running on Linux"` / `skip "not running on macOS"` — acceptable;
  each runs on its native CI runner.
- `skip "python3 not available"` — acceptable locally; python3 is available
  in CI.
- Never skip without a reason string.

### Known platform limitations

- Audio capture (`record-audio`), display brightness (`brightness`), and
  clipboard writes (`cb` real clipboard) require hardware devices; tests use
  stubs and are designed to skip gracefully in CI headless environments.
- `shell-banner` branding artwork and ANSI coloring evolve independently;
  tests use semantic assertions rather than full-output snapshots.

---

## Diagnosing a failed test

1. Run the failing file directly:

   ```sh
   bats tests/integration/entrypoint.bats
   bats tests/bin/generate-password.bats
   ```

2. Add `--verbose-run` or `--tap` for more output.

3. The test uses `$TEST_HOME` / `$BIN_TEST_HOME` (printed in failure output),
   not your real home directory. No personal configuration is involved.

4. To inspect the test environment, add a temporary `echo` or `env` call
   inside the failing test's command string and re-run.

---

## Production-change policy

If a test exposes a disagreement between the implementation and the
documented Mantle contract, make the **smallest focused correction** and
document it in the pull-request summary. Do not use tests as an excuse for
broad refactoring.
