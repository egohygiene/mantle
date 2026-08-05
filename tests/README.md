# Mantle Test Suite

This directory contains Mantle's behavioral test suite, organized into unit,
integration, and contract layers.

---

## Required local tools

| Tool | Minimum version | Purpose |
|------|----------------|---------|
| [Bats Core](https://github.com/bats-core/bats-core) | 1.5.0 | Test runner |
| Bash | 4.0+ | Required shell |
| Zsh | any | Optional (tests skip if absent) |
| Fish | any | Optional (tests skip if absent) |
| `shellcheck` | any | Static analysis (optional) |
| `shfmt` | any | Formatting check (optional) |

Install Bats using one of:

```sh
# macOS
brew install bats-core

# npm (cross-platform)
npm install -g bats

# From source
git clone https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh /usr/local
```

---

## Running the tests

### Run everything

```sh
./tests/run.sh
```

### Run one layer only

```sh
./tests/run.sh unit
./tests/run.sh integration
./tests/run.sh contract
./tests/run.sh static
```

### Run a single file

```sh
./tests/run.sh tests/unit/core/guards.bats
# or, using bats directly:
bats tests/integration/entrypoint.bats
```

### Run a single test by name

```sh
bats --filter "mantle_guard_has_command returns 0" tests/unit/core/guards.bats
```

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

Stubs are isolated per-test: `teardown_stub_dir` removes `$STUB_DIR` after
each test.

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

Required shells (`bash`, `zsh`, `fish`) are installed in CI so required
coverage never silently passes through skips.

### Which local skips are acceptable

- `skip "zsh is not available on this system"` — acceptable locally if Zsh
  is not installed; CI always has Zsh.
- `skip "not running on Linux"` / `skip "not running on macOS"` — acceptable;
  each runs on its native CI runner.
- Never skip without a reason string.

---

## Diagnosing a failed test

1. Run the failing file directly:

   ```sh
   bats tests/integration/entrypoint.bats
   ```

2. Add `--verbose-run` or `--tap` for more output.

3. The test uses `$TEST_HOME` (printed in failure output), not your real home
   directory. No personal configuration is involved.

4. To inspect the test environment, add a temporary `echo` or `env` call
   inside the failing test's command string and re-run.

---

## Production-change policy

If a test exposes a disagreement between the implementation and the
documented Mantle contract, make the **smallest focused correction** and
document it in the pull-request summary. Do not use tests as an excuse for
broad refactoring.
