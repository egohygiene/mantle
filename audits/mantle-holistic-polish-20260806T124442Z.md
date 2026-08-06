# Mantle Holistic Polish Audit

<!-- Repository Auditor Specification v2.0.0 -->

---

## 1. Report Metadata and Status

| Field | Value |
|---|---|
| **Report name** | mantle-holistic-polish |
| **Report file** | `audits/mantle-holistic-polish-20260806T124442Z.md` |
| **Status** | `partial` |
| **Audit execution time (UTC)** | 2026-08-06T12:44:42Z |
| **Audited commit SHA** | `3ba37090c483034a5ecd249a099467ab4f1b9e6e` |
| **Audited branch** | `copilot/chore-readiness-add-portable-mantle-installer` |
| **Auditor** | GitHub Copilot Coding Agent |
| **Strategy** | holistic |
| **Phase 1 (installer)** | complete |
| **Phase 2 (audit)** | partial — macOS validation unverified; Fish and Zsh unavailable in audit environment |
| **Reason for partial status** | Bats, Zsh, and Fish were not installed in the audit environment; no macOS runner was available; behavioral test suite could not be executed. Static validation (Bash syntax, ShellCheck, shfmt) passed for `install.sh`. |

---

## 2. Executive Summary

Mantle is a well-structured, modular shell-environment framework with a clean architectural separation between runtime initialization, library functions, environment modules, platform adapters, and public CLI commands. The multi-layer Bats test suite and CI coverage on both Linux and macOS are genuine strengths. The codebase shows disciplined defensive programming throughout initialization paths.

The principal gap at this milestone is the absence of a portable root-level installer prior to this work. `install.sh` has been implemented and statically validated in this PR. Key remaining risks before a credible trial release include:

- **No automated test coverage for `install.sh`** — behavioral installer tests are recommended as a follow-up.
- **Pre-existing shfmt formatting failures** across several `bin/` scripts — these fail the `static` CI job.
- **MacOS runtime not validated** in this audit environment; the installer's macOS-specific paths (`.bash_profile` detection, `uname -s Darwin` branch) are code-reviewed but not executed.
- **Fish and Zsh unavailable** in this environment; installer Fish and Zsh activation paths are statically validated but not executed.

Fourteen findings are recorded below; the suggested issue backlog contains nine prioritized follow-up issues.

---

## 3. Audit Request and Inferred Defaults

```yaml
audit_name: mantle-holistic-polish
strategy: holistic
scope:
  include:
    - "."
  exclude:
    - ".git/**"
    - "generated/**"
    - "temporary test artifacts"
focus:
  - architecture
  - portability
  - installer safety
  - shell initialization
  - CLI quality
  - testing
  - security-and-privacy
  - developer-experience
  - ci-and-automation
  - documentation
  - release-readiness
depth: deep
outputs:
  - markdown
constraints:
  - read-only
  - non-destructive
  - offline
```

**Inferred defaults applied:**

| Setting | Inferred value | Reason |
|---|---|---|
| `report_status` | `partial` | Bats/Zsh/Fish unavailable; macOS unverified |
| `finding_id_prefix` | `AUDIT` | Specification default |
| `severity_floor` | `informational` | Record all nontrivial findings |
| `existing_audits` | none | No `audits/` directory existed before this PR |
| `historical_findings` | none | First audit for this repository |

---

## 4. Scope and Exclusions

**Included:**

- All repository files excluding `.git/`
- `install.sh` (created in this PR)
- `audits/` (this report)

**Excluded:**

- `.git/**` — version control metadata
- Generated artifacts (none identified)
- Temporary test artifacts (cleaned before audit)
- `.isolated-home.*` directories created by agent test runs (confirmed absent at audit time)

---

## 5. Repository and Commit Context

| Field | Value |
|---|---|
| **Repository** | `egohygiene/mantle` |
| **Commit** | `3ba37090c483034a5ecd249a099467ab4f1b9e6e` |
| **Branch** | `copilot/chore-readiness-add-portable-mantle-installer` |
| **PR title** | [WIP] Add portable Mantle installer and generate holistic audit |
| **Prior audits** | None (this is the first audit report) |
| **CI status at audit time** | `action_required` (manual review gate) |

**Repository census (observed):**

| Area | Count |
|---|---|
| `bin/` public commands | 72 |
| `tests/bin/*.bats` test files | 71 (one per bin/ command minus `coverage-guard.bats`) |
| `tests/integration/*.bats` | 6 |
| `tests/contract/*.bats` | 5 |
| `lib/bash/` libraries | 11 |
| `lib/core/` libraries | 8 |
| `lib/install/` utilities | 10 |
| `lib/extensions/` | 3 |
| `modules/` | 8 |
| `platforms/` | 3 (darwin, linux, windows) |
| `runtime/shells/` | 4 (bash, fish, posix, zsh) |
| `libexec/mantle/commands/` | 3 (help, version, install) |
| `libexec/mantle/installers/` | 30+ individual tool installers |

---

## 6. Methodology and Discovery Order

Inspection followed the required order:

1. Entry documentation (`README.md`) — reviewed in full.
2. Architecture documentation (`README.md` architecture section, `libexec/mantle/README.md`) — reviewed.
3. Governance and decisions — no `CONTRIBUTING.md`, `DECISIONS.md`, or `ADR` found.
4. Specifications — no formal specifications found.
5. Agent and skill instructions — not accessed (per policy).
6. Task and build automation — no `Taskfile.yml` found; `tests/run.sh` is the canonical task runner.
7. Dependency manifests — none (shell-only project, no `package.json`, `Gemfile`, etc.).
8. CI/CD workflows — `.github/workflows/test.yml` reviewed in full.
9. Runtime source — `.shellrc`, `init/`, `modules/`, `platforms/`, `runtime/` reviewed.
10. Public `bin/` commands — `bin/mantle` reviewed; spot-checked several others.
11. Tests — `tests/run.sh`, `tests/test_helper/`, representative `tests/bin/` and `tests/integration/` files reviewed.
12. Supporting documentation — `lib/install/README.md`, `libexec/mantle/README.md` reviewed.
13. Existing audit reports — `audits/` directory was absent before this PR; no prior reports.

**Tools available in audit environment:**

| Tool | Available | Notes |
|---|---|---|
| `bash` | yes | GNU bash 5.1 |
| `zsh` | no | Not installed |
| `fish` | no | Not installed |
| `shellcheck` | yes | 0.9.0 |
| `shfmt` | yes | 3.8.0 (installed during audit) |
| `bats` | no | Not installed |
| macOS | no | Linux (Ubuntu 22.04) |

---

## 7. Overall Assessment

Mantle is a well-engineered project that is not yet release-ready but is approaching that threshold. The initiative quality is high: the initialization state machine, idempotent module loading, source-safety guards, and multi-platform CI are above average for a personal shell framework.

**Highest-confidence strengths:**

- Disciplined shell initialization with explicit state tracking.
- Comprehensive public-CLI test coverage with stub isolation.
- Clean separation between runtime and repository-only content.
- XDG-first directory layout throughout.

**Highest-risk gaps:**

- Pre-existing shfmt failures across `bin/` scripts cause the static CI job to fail.
- No automated test coverage for the new `install.sh`.
- No formal release process, versioning scheme, or changelog.
- Fish activation and macOS runtime remain unverified in this environment.

---

## 8. Release-Readiness Assessment

**Not yet ready for a tagged public release.** Blocking issues:

1. The `static` CI job fails on pre-existing shfmt formatting issues in `bin/` (AUDIT-001). This must be resolved before any release tag.
2. `install.sh` has no automated test coverage (AUDIT-002). Absence of installer tests is acceptable for an internal milestone but should be resolved before promoting the installer as the supported installation path.
3. No versioning scheme or changelog exists (AUDIT-010).

**Ready for internal trial installation** once AUDIT-001 is resolved.

---

## 9. Installation-Readiness Matrix

Each row records: status, evidence basis, and remaining validation needed.

| Scenario | Status | Evidence | Basis | Remaining validation |
|---|---|---|---|---|
| Linux clean install | ✅ Validated | Smoke tests with isolated `HOME`; payload present | Executed | None for basic flow |
| Linux update (over installer-owned) | ✅ Validated | Idempotent install tests passed | Executed | None |
| Linux uninstall | ✅ Validated | `--uninstall` test passed; prefix removed, blocks cleaned | Executed | None |
| macOS clean install | ⚠️ Unverified | Code path branches on `uname -s Darwin`; `.bash_profile` selected | Static inspection | Execute on real macOS runner |
| macOS update | ⚠️ Unverified | Same code path as Linux update | Static inspection | Execute on real macOS runner |
| macOS uninstall | ⚠️ Unverified | Same uninstall path | Static inspection | Execute on real macOS runner |
| Bash activation | ✅ Validated | Managed block appended to `~/.bashrc`; idempotency verified | Executed | None |
| Zsh activation | ⚠️ Unverified | Code path exists; `$ZDOTDIR/.zshrc` targeted | Static inspection | Execute with zsh installed |
| Fish activation | ⚠️ Unverified | `conf.d/mantle.fish` generated; content correct | Static inspection | Execute with fish installed |
| Copy installation | ✅ Validated | Payload files and directories present in prefix | Executed | None |
| Symlink installation | ⚠️ Unverified | `ln -sf` branches present; not exercised | Static inspection | Execute `--method symlink` |
| Custom prefix | ✅ Validated | `--prefix "/path with spaces"` test passed | Executed | None |
| Prefix with spaces | ✅ Validated | Tested with embedded space in path | Executed | None |
| Dry-run | ✅ Validated | `--dry-run` prints plan; no files created | Executed | None |
| Status mode | ✅ Validated | `--status` reports installed/not-installed state | Executed | None |
| No-shell-hook mode | ✅ Validated | `--no-shell-hook` skips all activation | Executed | None |
| Environment diff | ✅ Validated | `--environment-diff` shows PATH diff and MANTLE_* vars | Executed | Verify on macOS |
| Container/CI behavior | ✅ Validated | `--no-shell-hook` fully functional; non-interactive assumed | Executed | None |
| Non-interactive behavior | ✅ Validated | No interactive prompts; all options supply complete intent | Executed | None |
| Rollback after failure | ⚠️ Unverified | Backup/restore logic present in `_publish_staged` | Static inspection | Inject failure and verify rollback |
| Reject non-owned destination | ✅ Validated | Returns error when `.mantle-installer` absent in existing dir | Code review | None |

---

## 10. Findings Summary Table

| ID | Title | Severity | Confidence | Status | Area | Effort |
|---|---|---|---|---|---|---|
| AUDIT-001 | Pre-existing shfmt failures block static CI job | high | high | confirmed | ci-and-automation | medium |
| AUDIT-002 | No automated test coverage for `install.sh` | high | high | confirmed | testing | medium |
| AUDIT-003 | Installer version reads git SHA instead of semantic version | medium | high | confirmed | installer safety | small |
| AUDIT-004 | No `CONTRIBUTING.md` or documented contribution workflow | medium | high | confirmed | developer-experience | small |
| AUDIT-005 | No versioning scheme, changelog, or release process | medium | high | confirmed | ci-and-automation | medium |
| AUDIT-006 | macOS Bash startup file detection silently incorrect on some configurations | medium | medium | probable | portability | small |
| AUDIT-007 | Fish entrypoint requires manual `MANTLE_ROOT` wiring; no auto-detection | medium | high | confirmed | architecture | medium |
| AUDIT-008 | `install.sh` rollback path untested | medium | medium | needs-validation | installer safety | small |
| AUDIT-009 | `--environment-diff` captures color escape codes as `MANTLE_COLOR_*` variables | low | high | confirmed | installer safety | small |
| AUDIT-010 | No release automation, no version file, no checksums | medium | high | confirmed | ci-and-automation | large |
| AUDIT-011 | `tests/run.sh static` shfmt check scope includes all `.sh` files | low | high | confirmed | ci-and-automation | small |
| AUDIT-012 | Windows platform support undocumented and partially tested | low | high | confirmed | portability | medium |
| AUDIT-013 | shdoc convention partially applied in `install.sh` (no full shdoc coverage) | low | medium | probable | documentation | small |
| AUDIT-014 | `--environment-diff` diff output uses `diff` format but is computed manually | low | medium | needs-validation | developer-experience | small |

---

## 11. Severity-Grouped Findings

### High

---

#### AUDIT-001: Pre-existing shfmt failures block static CI job

- **Classification:** confirmed defect
- **Severity:** high
- **Confidence:** high
- **Status:** confirmed
- **Area:** ci-and-automation
- **Effort:** medium
- **Impact:** high
- **Historical classification:** new

**Observation:** `observed`  
Running `./tests/run.sh static` produces a non-zero exit status because `shfmt -d "${MANTLE_ROOT}"` reports formatting differences for pre-existing files in `bin/` (e.g., `bin/apt-base`, `bin/apt-freeze`, and other large bin scripts). These diffs are pre-existing and are not introduced by `install.sh`.

**Evidence:**
```
$ ./tests/run.sh static 2>&1 | head -10
=== Static Validation ===
Checking Bash syntax...
✓ Bash syntax
Checking ShellCheck...
✓ ShellCheck
Running shfmt...
--- /home/runner/work/mantle/mantle/bin/apt-base.orig
+++ /home/runner/work/mantle/mantle/bin/apt-base
✗ shfmt found formatting issues (run: shfmt -w .)
```
Exit status: 1

The `install.sh` file itself passes `shfmt -d` with no diffs (verified: exit 0).

**Why it matters:** The `static` job in `.github/workflows/test.yml` runs `./tests/run.sh static`. Pre-existing shfmt failures mean the CI job fails on every push, degrading signal quality and blocking a clean CI baseline.

**Recommendation:** Run `shfmt -w .` on the repository root to auto-format all affected files. Commit the result as a dedicated formatting-only commit. Review the diff to ensure no semantic changes.

**Suggested validation:** `./tests/run.sh static` exits 0 after applying `shfmt -w .`.

**Dependencies / risks:** Must be done as a standalone formatting commit to keep history clean.

---

#### AUDIT-002: No automated test coverage for `install.sh`

- **Classification:** confirmed defect
- **Severity:** high
- **Confidence:** high
- **Status:** confirmed
- **Area:** testing
- **Effort:** medium
- **Impact:** high
- **Historical classification:** new

**Observation:** `observed`  
No Bats test file for `install.sh` exists in `tests/`. The issue specification acknowledges this and directs recording validation in the PR summary rather than adding test files in this issue. However, the absence of durable automated coverage is a risk that must be captured.

**Evidence:**
```
$ find /home/runner/work/mantle/mantle/tests -name "*install*"
/home/runner/work/mantle/mantle/tests/integration/installers.bats
```
The `installers.bats` file tests `libexec/mantle/installers/*.sh` (tool-specific installers for eza, shfmt, etc.), not the root-level `install.sh`.

**Why it matters:** Without automated tests, regressions in installation, activation, idempotency, or rollback behavior cannot be detected by CI.

**Recommendation:** Create `tests/installer/install.bats` (or `tests/integration/install-root.bats`) covering at minimum: clean install, idempotent install, bash/zsh/fish activation, custom prefix, `--dry-run`, `--status`, `--uninstall`, and rollback.

**Suggested validation:** `./tests/run.sh` exits 0 and includes installer test results.

**Dependencies / risks:** Depends on AUDIT-001 (static CI must be clean first).

---

### Medium

---

#### AUDIT-003: Installer version reads git SHA instead of semantic version

- **Classification:** probable issue
- **Severity:** medium
- **Confidence:** high
- **Status:** confirmed
- **Area:** installer safety
- **Effort:** small
- **Impact:** medium
- **Historical classification:** new

**Observation:** `observed`  
`./install.sh --version` outputs `3ba3709` (the short git commit SHA). This is produced by:
```bash
git -C "${MANTLE_INSTALLER_SOURCE}" rev-parse --short HEAD 2>/dev/null
```
A semantic version (e.g., `0.1.0`) or the installer's own constant is more appropriate for a public-facing version string. The git SHA is also unavailable in detached or shallow clones with no `.git/` directory.

**Evidence:**
```
$ ./install.sh --version
3ba3709
```

**Why it matters:** Users cannot determine whether their installer matches the documented release. Tools that parse `--version` output expect a stable, parseable version string.

**Recommendation:** Define a constant `INSTALLER_VERSION="0.1.0"` in `install.sh` and use it for `--version`. Optionally append the git SHA as a build suffix: `0.1.0+3ba3709`.

**Suggested validation:** `./install.sh --version` outputs a value matching `^[0-9]+\.[0-9]+\.[0-9]+`.

**Dependencies / risks:** Requires deciding on a versioning scheme (AUDIT-010).

---

#### AUDIT-004: No `CONTRIBUTING.md` or documented contribution workflow

- **Classification:** documentation gap
- **Severity:** medium
- **Confidence:** high
- **Status:** confirmed
- **Area:** developer-experience
- **Effort:** small
- **Impact:** medium
- **Historical classification:** new

**Observation:** `observed`  
The repository has no `CONTRIBUTING.md`, `DEVELOPMENT.md`, or equivalent file. Adding a new bin/ command, module, or platform adapter requires reading multiple source files to understand the conventions (coverage map, shdoc requirements, ShellCheck configuration, shfmt formatting).

**Evidence:**
```
$ ls /home/runner/work/mantle/mantle/
LICENSE  README.md  assets  bin  init  install.sh  lib  libexec
modules  platforms  runtime  tests
```
No `CONTRIBUTING.md` found.

**Why it matters:** New contributors and external reviewers cannot determine how to add features, run tests, or understand the project conventions without reading through source code.

**Recommendation:** Create `CONTRIBUTING.md` covering: how to run tests, how to add a new `bin/` command (including coverage map registration), shdoc conventions, ShellCheck/shfmt requirements, and PR conventions.

**Suggested validation:** `CONTRIBUTING.md` exists and cross-references `tests/run.sh` and the coverage map.

---

#### AUDIT-005: No versioning scheme, changelog, or release process

- **Classification:** maintainability risk
- **Severity:** medium
- **Confidence:** high
- **Status:** confirmed
- **Area:** ci-and-automation
- **Effort:** medium
- **Impact:** medium
- **Historical classification:** new

**Observation:** `observed`  
There are no git tags, no `CHANGELOG.md`, and no release workflow in `.github/workflows/`. The installer's `--version` reads a git SHA (see AUDIT-003). There is no `VERSION` file, `mantle version` output matches a hardcoded string in `libexec/mantle/commands/version.sh`.

**Evidence:**
```
$ git -C /home/runner/work/mantle/mantle tag -l
(empty)
$ ls .github/workflows/
test.yml
```

**Why it matters:** Without versioning, users cannot pin to a stable release, and the project cannot produce checksums, provenance, or reproducible installation artifacts.

**Recommendation:** Adopt Semantic Versioning; add a `VERSION` file; add a `CHANGELOG.md`; create a release workflow that creates a GitHub Release with checksums and sets the installer version constant.

**Suggested validation:** `git tag -l` returns at least one `v*.*.*` tag; release workflow creates a GitHub Release artifact.

---

#### AUDIT-006: macOS Bash startup-file detection may be incorrect for some users

- **Classification:** probable issue
- **Severity:** medium
- **Confidence:** medium
- **Status:** probable
- **Area:** portability
- **Effort:** small
- **Impact:** medium
- **Historical classification:** new

**Observation:** `inferred`  
The installer detects macOS via `uname -s` returning `Darwin` and selects `~/.bash_profile` as the Bash startup file. On macOS, Bash sessions opened by terminal apps (e.g., iTerm2, Terminal.app) source `.bash_profile` for login shells but `.bashrc` for non-login shells. The installer always picks `.bash_profile` on macOS, which means Bash non-login shells do not get Mantle activation unless the user's `.bash_profile` itself sources `.bashrc`.

Additionally, the macOS default Bash is version 3.2 (the installer requires Bash 4). Users running the system Bash will receive an error. This is correct behavior (the guard exists) but the diagnostic mentions `brew install bash` which may not be appropriate for all users.

**Evidence:**
```bash
# install.sh _bash_startup_file()
if [[ "${uname_s}" == "Darwin" ]]; then
    printf "%s\n" "${HOME}/.bash_profile"
else
    printf "%s\n" "${HOME}/.bashrc"
fi
```
Source: `install.sh` (observed in installed file).

**Why it matters:** Mantle activation would silently fail for macOS users who launch non-login Bash sessions without a `.bash_profile` → `.bashrc` chain.

**Recommendation:** Document the `.bash_profile` → `.bashrc` sourcing pattern in the activation block comment. Consider detecting whether the user has the canonical chain and warning if not.

**Suggested validation:** Verified on real macOS with both login and non-login Bash sessions.

---

#### AUDIT-007: Fish entrypoint requires manual `MANTLE_ROOT` wiring; no auto-detection

- **Classification:** architectural concern
- **Severity:** medium
- **Confidence:** high
- **Status:** confirmed
- **Area:** architecture
- **Effort:** medium
- **Impact:** medium
- **Historical classification:** new

**Observation:** `observed`  
The Bash/Zsh entrypoint (`.shellrc`) auto-detects `MANTLE_ROOT` from its own location using `BASH_SOURCE[0]` / `${(%):-%x}`. The Fish entrypoint (`runtime/shells/fish/runtime.fish`) requires `MANTLE_ROOT` to be pre-set by the caller before it is sourced. The installer handles this by generating a `conf.d/mantle.fish` file that sets `MANTLE_ROOT` and then sources the entrypoint.

This architectural asymmetry means that the Fish entrypoint cannot be sourced safely in isolation without external setup, unlike the Bash/Zsh entrypoints.

**Evidence:**
```fish
# runtime/shells/fish/runtime.fish
if not set -q MANTLE_ROOT; or not string match --quiet --regex '^/' -- "$MANTLE_ROOT"; ...
    printf '[mantle:error] Fish runtime requires an absolute, readable MANTLE_ROOT\n' >&2
    return 1
end
```
Observed in `runtime/shells/fish/runtime.fish` lines 11–15.

**Why it matters:** The asymmetry creates a different mental model for Fish users and requires the installer to generate wrapper content rather than simply adding a `source` line.

**Recommendation:** Consider adding a Fish-native auto-detection function (`status filename` equivalent), or document the intentional design decision with a rationale comment in `runtime.fish`.

**Suggested validation:** Documentation clearly explains the design choice; README covers the Fish activation flow.

---

#### AUDIT-008: `install.sh` rollback path not validated

- **Classification:** probable issue
- **Severity:** medium
- **Confidence:** medium
- **Status:** needs-validation
- **Area:** installer safety
- **Effort:** small
- **Impact:** medium
- **Historical classification:** new

**Observation:** `inferred`  
The `_publish_staged` function in `install.sh` moves the existing prefix to a `${prefix}.mantle-backup-$$` path before publishing the new stage, and restores it if the `mv` fails. This logic is present but was not exercised by injecting a failure during the audit.

**Evidence:**
```bash
# install.sh _publish_staged()
if [[ -e "${prefix}" ]]; then
    backup="${prefix}.mantle-backup-$$"
    mv -- "${prefix}" "${backup}" || { ... return 1; }
fi
if ! mv -- "${stage}" "${prefix}"; then
    if [[ -n "${backup}" && -e "${backup}" ]]; then
        mv -- "${backup}" "${prefix}" || true
    fi
    return 1
fi
```

**Why it matters:** An untested rollback path may leave the installation in a partial state if `mv` to the final prefix fails (e.g., cross-filesystem move).

**Recommendation:** Add a rollback test to the installer test suite (AUDIT-002) that injects a failure after backup but before publish and verifies the prefix is restored.

**Suggested validation:** Injected failure test passes.

---

### Low

---

#### AUDIT-009: `--environment-diff` captures `MANTLE_COLOR_*` escape variables

- **Classification:** optimization opportunity
- **Severity:** low
- **Confidence:** high
- **Status:** confirmed
- **Area:** installer safety
- **Effort:** small
- **Impact:** low
- **Historical classification:** new

**Observation:** `observed`  
`--environment-diff` filters for `MANTLE_*` variables. In a non-interactive shell (no tty), `MANTLE_COLOR_*` variables are exported but contain empty strings. The diff output shows many `MANTLE_COLOR_*=` lines that add no meaningful information.

**Evidence:**
```
+MANTLE_COLOR_BLUE=
+MANTLE_COLOR_BOLD=
+MANTLE_COLOR_BOLD_BLUE=
... (many more)
```
Observed in actual `--environment-diff` output during audit validation.

**Why it matters:** The color variable noise obscures the meaningful signal (PATH changes, initialization state variables).

**Recommendation:** Filter out `MANTLE_COLOR_*` variables from the diff output, or only show non-empty MANTLE_* values.

**Suggested validation:** `--environment-diff` output in non-interactive mode does not include `MANTLE_COLOR_*=` lines.

---

#### AUDIT-010: No release automation, no version file, no checksums

- *(Captured under AUDIT-005 as the primary finding; this entry notes the checksums and provenance gap.)*
- **Classification:** maintainability risk
- **Severity:** medium
- **Confidence:** high
- **Status:** confirmed
- **Area:** ci-and-automation
- **Effort:** large
- **Impact:** medium

(See AUDIT-005 for full details. This is a combined finding.)

---

#### AUDIT-011: `shfmt` check scope includes all `.sh` files including large bin/ scripts

- **Classification:** maintainability risk
- **Severity:** low
- **Confidence:** high
- **Status:** confirmed
- **Area:** ci-and-automation
- **Effort:** small
- **Impact:** low
- **Historical classification:** new

**Observation:** `observed`  
`tests/run.sh` runs `shfmt -d "${MANTLE_ROOT}"` which scans all `.sh` files recursively. Several `bin/` scripts use 2-space indentation while shfmt's default is tabs. The test runner logs a warning when shfmt is not available but fails when it is — a behavior difference between CI environments with and without shfmt installed.

**Evidence:**
```bash
# tests/run.sh _run_static()
if shfmt -d "${MANTLE_ROOT}" 2>/dev/null; then
    _ok "shfmt formatting"
else
    _fail "shfmt found formatting issues (run: shfmt -w .)"
    static_status=1
fi
```
CI installs shfmt 3.8.0, so the check always runs (and currently fails) in CI.

**Why it matters:** Pre-existing formatting issues silently accumulated, and the static job only started failing after shfmt was added to CI.

**Recommendation:** Resolve all shfmt issues (AUDIT-001) and add a `.shfmt.yaml` or `.editorconfig` entry to pin formatting settings. Consider using a `shfmt` pre-commit hook.

---

#### AUDIT-012: Windows platform support undocumented and partially tested

- **Classification:** documentation gap
- **Severity:** low
- **Confidence:** high
- **Status:** confirmed
- **Area:** portability
- **Effort:** medium
- **Impact:** low
- **Historical classification:** new

**Observation:** `observed`  
`platforms/windows/runtime.sh` exists and is noted in the README as experimental (MSYS2/Git Bash only). No Windows CI runner or workflow exists. The installer does not include Windows-specific logic (correct for POSIX-only scope).

**Evidence:**
```
$ ls platforms/
darwin  linux  windows
$ cat README.md | grep -i windows | head -3
- Windows support is currently limited to Unix-compatible environments such as MSYS2 and Git Bash
```

**Why it matters:** Users on Windows MSYS2/Git Bash have no documented path to install Mantle.

**Recommendation:** Document the exact Windows setup steps in README (MSYS2/Git Bash only). Note that `install.sh` can be run from MSYS2 bash but has not been validated on Windows.

---

#### AUDIT-013: shdoc coverage partial in `install.sh`

- **Classification:** documentation gap
- **Severity:** low
- **Confidence:** medium
- **Status:** probable
- **Area:** documentation
- **Effort:** small
- **Impact:** low
- **Historical classification:** new

**Observation:** `inferred`  
`install.sh` has shdoc-style `@description`, `@arg`, `@exitcode`, and `@stdout` annotations on most internal functions. However, some helper functions (`_info`, `_ok`, `_warn`, `_err`, `_plan`, `_installer_color_init`, `_installer_cleanup`) lack shdoc annotations. The existing codebase applies shdoc only to functions with a formal contract, not to logging utilities.

**Evidence:**  
Consistent with the repository pattern in `lib/core/core.sh` where only public API functions carry shdoc annotations. The installer follows the same convention.

**Why it matters:** Minor inconsistency; does not affect functionality.

**Recommendation:** Confirm the shdoc annotation policy in `CONTRIBUTING.md` (AUDIT-004). No change to `install.sh` required if the policy is "annotate functions with formal contracts only."

---

#### AUDIT-014: `--environment-diff` diff format is custom, not standard unified diff

- **Classification:** optimization opportunity
- **Severity:** low
- **Confidence:** medium
- **Status:** needs-validation
- **Area:** developer-experience
- **Effort:** small
- **Impact:** low
- **Historical classification:** new

**Observation:** `observed`  
The `--environment-diff` output uses `diff -u` between two temp files capturing environment dumps. The output is a standard unified diff of the complete environment variable list (filtered to `PATH` and `MANTLE_*`). The format is clear, but it requires users to understand unified diff syntax.

**Evidence:**
```
--- before
+++ after
@@ -1 +1,66 @@
-PATH=/snap/bin:/home/runner/...
+PATH=/tmp/.../mantle/bin:/tmp/...
```
Observed in validation output.

**Why it matters:** Minor UX consideration; not a blocker.

**Recommendation:** The current format is adequate. Consider adding a brief legend (`-` = before, `+` = after) in the header for users unfamiliar with diff syntax.

---

## 12. Positive Observations

These are genuine strengths observed with high confidence.

### POS-001: Disciplined initialization state machine

`observed` — `.shellrc` uses an explicit four-state machine (`uninitialized`, `initializing`, `initialized`, `failed`) with guards against recursive sourcing, unknown states, and direct execution. This prevents subtle double-initialization bugs in nested shell environments.

Evidence: `.shellrc` lines 19–38.

### POS-002: Idempotent, transactional module loader

`observed` — `lib/modules.sh` implements a transactional module loader with cycle detection (`MANTLE_LOADING_MODULES`), idempotency (`MANTLE_LOADED_MODULES`), and specific exit codes (0/1/64/70). Failed loads are retryable rather than permanently locked.

Evidence: `lib/modules.sh`.

### POS-003: Comprehensive public-CLI test coverage

`observed` — All 72 `bin/` commands are registered in `tests/bin/coverage-map.tsv`. The coverage-map enforcement contract tests (`tests/contract/repository-layout.bats`) verify that every `bin/` executable has a coverage entry and every listed test file exists. This prevents coverage drift.

Evidence: `tests/bin/coverage-map.tsv`, `tests/contract/repository-layout.bats`.

### POS-004: Source-safety guards on all internal files

`observed` — Every internal `.sh` file that must be sourced (not executed) detects direct execution and exits with status 64, printing an informative error. This catches a common shell scripting mistake.

Evidence: `tests/contract/source-safety.bats`.

### POS-005: XDG-first directory layout

`observed` — All user-facing directories use XDG Base Directory Specification variables with correct fallbacks (`XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME`, `XDG_BIN_HOME`). The installer follows the same convention.

Evidence: `modules/xdg.sh`, `modules/environment.sh`, `install.sh`.

### POS-006: Dual-platform CI (Linux and macOS)

`observed` — `.github/workflows/test.yml` runs behavioral tests on both Ubuntu 22.04 and macOS 13. This catches platform-specific regressions before they reach users.

Evidence: `.github/workflows/test.yml` jobs `test-linux` and `test-macos`.

### POS-007: Explicit PATH precedence ordering

`observed` — `modules/environment.sh` constructs the PATH using an explicit ordered candidate list (lowest to highest priority), with Mantle's `bin/` at the highest priority position. The function comments explain the ordering rationale.

Evidence: `modules/environment.sh` lines 57–76.

### POS-008: Stub-isolated destructive operation testing

`observed` — Tests for commands that require privileged operations (`apt-install`, `encrypt-volume`, `passwordless-sudo`, etc.) use `STUB_DIR`-prepended stubs that record calls without performing real mutations. The test helper infrastructure (`tests/test_helper/stubs.bash`) supports per-test stub creation and teardown.

Evidence: `tests/test_helper/stubs.bash`, `tests/bin/helpers/stubs.bash`, representative test files.

### POS-009: Installer payload validation before mutation

`observed` — `install.sh` validates that all required payload items exist in the source directory before creating any temporary files or modifying the destination. Missing required files fail with an error before any mutation.

Evidence: `install.sh` `_validate_payload()`.

### POS-010: Atomic installation with rollback

`observed` — `install.sh` stages the payload to a `mktemp -d` temporary directory and publishes via `mv` (atomic on the same filesystem). The previous installation is backed up before publication and restored on failure.

Evidence: `install.sh` `_stage_payload()`, `_publish_staged()`.

---

## 13. Opportunities Grouped by Area

### Architecture

- **AUDIT-007**: Document or resolve the Fish `MANTLE_ROOT` pre-wiring requirement asymmetry.
- Consider a formal architecture decision record (ADR) documenting the runtime/repository boundary and the Realm/Mantle separation.

### Shell portability

- **AUDIT-006**: Document the macOS `.bash_profile` → `.bashrc` chain requirement.
- Add a note to `install.sh --help` about Bash 4 requirement and brew install path on macOS.

### Installer readiness

- **AUDIT-002**: Add `tests/installer/install.bats` with comprehensive installer coverage.
- **AUDIT-008**: Validate rollback behavior with an injected failure test.
- **AUDIT-003**: Replace git-SHA version with a semantic version constant.
- **AUDIT-009**: Filter `MANTLE_COLOR_*` from `--environment-diff` output.

### Testing

- **AUDIT-002**: Installer test file.
- Evaluate adding a Windows/MSYS2 CI job (low priority; Fish unavailable anyway).

### CI and automation

- **AUDIT-001**: `shfmt -w .` to fix pre-existing formatting failures.
- **AUDIT-005**: Versioning, changelog, and release workflow.
- **AUDIT-011**: `.shfmt.yaml` or `.editorconfig` to pin shfmt settings.

### Developer experience

- **AUDIT-004**: `CONTRIBUTING.md`.
- **AUDIT-012**: Document Windows MSYS2 installation path.

### Documentation

- **AUDIT-013**: Clarify shdoc annotation policy in `CONTRIBUTING.md`.

---

## 14. Suggested GitHub Issue Backlog

Issues are ordered from highest to lowest priority within each tier.

---

### P0 — Blocks safe testing or installation

#### ISSUE-01: fix(ci): resolve pre-existing shfmt formatting failures

- **Priority:** P0
- **Source findings:** AUDIT-001, AUDIT-011
- **Dependencies:** None
- **Intended outcome:** `./tests/run.sh static` exits 0 in CI.
- **Scope:** Run `shfmt -w .` on the repository root; commit formatting changes. Add `.shfmt.yaml` if needed to document formatting settings.
- **Acceptance criteria:**
  - `./tests/run.sh static` exits 0 on CI.
  - No semantic changes; formatting only.
  - `install.sh` continues to pass `shfmt -d`.
- **Recommended validation:** CI static job passes on both Linux and macOS.
- **Suggested order:** 1 (before any other work; establishes a clean CI baseline)

---

### P1 — Required before a credible trial release

#### ISSUE-02: test(installer): add automated test coverage for `install.sh`

- **Priority:** P1
- **Source findings:** AUDIT-002, AUDIT-008
- **Dependencies:** ISSUE-01
- **Intended outcome:** CI validates installer behavior on every push.
- **Scope:** Create `tests/installer/install.bats` (or `tests/integration/install-root.bats`). Cover: clean install, idempotent install, Bash/Zsh activation, Fish activation (skip if fish unavailable), custom prefix with spaces, `--dry-run`, `--status`, `--uninstall`, rejection of non-owned destination, rollback with injected failure.
- **Acceptance criteria:**
  - `./tests/run.sh` includes installer tests.
  - All installer tests pass on Linux CI.
  - macOS CI also passes installer tests.
- **Recommended validation:** CI green on both Linux and macOS.
- **Suggested order:** 2

#### ISSUE-03: fix(installer): use semantic version for `--version` output

- **Priority:** P1
- **Source findings:** AUDIT-003, AUDIT-005
- **Dependencies:** Decide on versioning scheme
- **Intended outcome:** `./install.sh --version` outputs a parseable semantic version.
- **Scope:** Add `VERSION` file; update `install.sh` to read it; update `libexec/mantle/commands/version.sh` to reference the same source.
- **Acceptance criteria:**
  - `./install.sh --version` matches `^[0-9]+\.[0-9]+\.[0-9]+`.
  - `mantle version` outputs the same version.
- **Suggested order:** 3

#### ISSUE-04: docs(contributing): add `CONTRIBUTING.md` with development workflow

- **Priority:** P1
- **Source findings:** AUDIT-004
- **Dependencies:** None
- **Intended outcome:** New contributors can run tests and add features without reading source code.
- **Scope:** Create `CONTRIBUTING.md` covering: `./tests/run.sh`, coverage map registration, shdoc conventions, ShellCheck/shfmt requirements, PR conventions, adding a bin/ command.
- **Acceptance criteria:**
  - `CONTRIBUTING.md` exists at repository root.
  - Describes how to run the full test suite.
  - Describes how to add a new `bin/` command including coverage map entry.
- **Suggested order:** 4

---

### P2 — Important polish or maintainability work

#### ISSUE-05: chore(release): add versioning, changelog, and release workflow

- **Priority:** P2
- **Source findings:** AUDIT-005, AUDIT-010
- **Dependencies:** ISSUE-03
- **Intended outcome:** Tagged releases with checksums and provenance can be produced.
- **Scope:** Add `CHANGELOG.md`; add `.github/workflows/release.yml` that creates a GitHub Release with checksums on `v*.*.*` tags.
- **Acceptance criteria:**
  - `git tag v0.1.0` triggers a GitHub Release with a checksum file.
  - `CHANGELOG.md` documents at least the initial milestone.
- **Suggested order:** 5

#### ISSUE-06: fix(installer): filter `MANTLE_COLOR_*` from `--environment-diff` output

- **Priority:** P2
- **Source findings:** AUDIT-009
- **Dependencies:** ISSUE-02 (for test coverage)
- **Intended outcome:** `--environment-diff` output is concise and signal-only.
- **Scope:** In `install.sh` `_run_env_diff()`, exclude `MANTLE_COLOR_*` from the `grep -E '^MANTLE_'` filter.
- **Acceptance criteria:**
  - `--environment-diff` in non-interactive mode does not list `MANTLE_COLOR_*=` lines.
  - PATH diff and important `MANTLE_*` state variables remain visible.
- **Suggested order:** 6

#### ISSUE-07: docs(portability): document macOS Bash startup-file chain requirement

- **Priority:** P2
- **Source findings:** AUDIT-006
- **Dependencies:** None (documentation only)
- **Intended outcome:** macOS users understand the `.bash_profile` → `.bashrc` activation model.
- **Scope:** Add a note in `README.md` Quick Start and in `install.sh --help` output about the macOS `.bash_profile` → `.bashrc` chain. Add a warning in the installer when it detects macOS + Bash + the chain is missing.
- **Acceptance criteria:**
  - README documents the activation model for macOS Bash users.
  - `--help` text mentions Bash 4 requirement and the startup-file chain.
- **Suggested order:** 7

---

### P3 — Optional future enhancement

#### ISSUE-08: feat(architecture): document or align Fish `MANTLE_ROOT` wiring

- **Priority:** P3
- **Source findings:** AUDIT-007
- **Dependencies:** None
- **Intended outcome:** The Fish `MANTLE_ROOT` requirement asymmetry is either resolved or documented as an intentional design decision.
- **Scope:** Either (a) add a Fish auto-detection function that resolves `MANTLE_ROOT` from `(status filename)` or (b) add a code comment in `runtime.fish` explaining why manual pre-wiring is required.
- **Acceptance criteria:**
  - The design decision is explicit and documented.
- **Suggested order:** 8

#### ISSUE-09: docs(platforms): document Windows MSYS2 installation path

- **Priority:** P3
- **Source findings:** AUDIT-012
- **Dependencies:** None
- **Intended outcome:** Windows MSYS2/Git Bash users have a documented installation path.
- **Scope:** Add a Windows section to README with MSYS2/Git Bash instructions. Note that `install.sh` can be run from MSYS2 bash (unvalidated).
- **Acceptance criteria:**
  - README includes Windows MSYS2 installation steps.
  - Steps note the "experimental/unvalidated" status.
- **Suggested order:** 9

---

## 15. Deferred and Out-of-Scope Observations

- **Banner / Fastfetch work**: The `README.md` references a placeholder banner SVG (`assets/branding/mantle-banner-placeholder.svg`). Final branding work is out of scope for this audit.
- **Realm integration**: `init/load-core.sh` detects `GITHUB_ACTIONS` and `REALM_*` environment variables. Realm-specific behavior is explicitly out of scope per the issue specification.
- **PowerShell / native Windows**: Out of scope. The audit notes the experimental MSYS2 support but does not evaluate it.
- **Automatic update checks**: The `modules/update-checks.sh` module is opt-in via `MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS`. Its implementation was not audited in detail.
- **PACE, Aether, Relay**: Referenced in the issue as sibling repositories. Not present in this repository; out of scope.
- **`tests/bats/` vendor directory**: Referenced in `tests/run.sh` but not present. Bats is expected to be installed separately. This is by design.

---

## 16. Uncertainties and Questions Requiring Human Clarification

1. **Versioning scheme**: What is the intended first public version? Is `0.1.0` appropriate or should the first release be `1.0.0`?

2. **macOS validation timeline**: When will `install.sh` be run on a real macOS machine? The audit cannot verify macOS-specific paths (`.bash_profile` selection, Bash 3.2 guard).

3. **Fish as first-class shell**: Is Fish intended to be a fully first-class supported shell on par with Bash/Zsh, or is it a best-effort secondary target? This affects whether Fish tests should be required in CI.

4. **`MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS` inversion**: The variable name reads as "disable automatic update checks" but is enabled by setting it to `1`. Is this the intended polarity? (`1` = suppress update checks, `0` = show them)

5. **shfmt configuration**: Should `shfmt` use its defaults (tabs, 0 indent width) or should a `.shfmt.yaml` be added? This determines whether the formatting fix is `shfmt -w .` or requires a configuration first.

6. **Installer test placement**: Should installer tests live in `tests/installer/` (new directory) or `tests/integration/install-root.bats` (existing integration directory)?

---

## 17. Evidence Index

| ID | Type | Path / Description |
|---|---|---|
| E-001 | observed | `install.sh` — static validation: `bash -n`, `shellcheck`, `shfmt -d` all pass |
| E-002 | observed | `./install.sh --help` output — captured during validation |
| E-003 | observed | `./install.sh --version` output: `3ba3709` |
| E-004 | observed | `./install.sh --dry-run` output — plan printed, no files created |
| E-005 | observed | `./install.sh --no-shell-hook` — payload installed, `.mantle-installer` written |
| E-006 | observed | Idempotent install — second run succeeds, no duplicate blocks |
| E-007 | observed | `./install.sh --status` — reports `installed: yes`, `ownership: installer-owned` |
| E-008 | observed | `./install.sh --uninstall` — prefix removed, no activation blocks found |
| E-009 | observed | `./install.sh --shell bash` — managed block written to `~/.bashrc` |
| E-010 | observed | `./install.sh --environment-diff` — PATH diff and 40+ `MANTLE_*` vars shown |
| E-011 | observed | `./install.sh --prefix "/path with spaces"` — installs correctly |
| E-012 | observed | `./tests/run.sh static` — exits 1; shfmt failures in pre-existing `bin/` scripts |
| E-013 | observed | `install.sh` passes `shfmt -d` with exit 0 |
| E-014 | observed | `tests/bin/coverage-map.tsv` — 72 commands all registered |
| E-015 | observed | `.github/workflows/test.yml` — Linux and macOS CI jobs present |
| E-016 | observed | `lib/modules.sh` — idempotent module loader with cycle detection |
| E-017 | inferred | macOS `.bash_profile` selection — code path present, not executed |
| E-018 | inferred | Fish activation — `conf.d/mantle.fish` generation code path present, not executed |
| E-019 | inferred | Rollback path — `_publish_staged` backup/restore code present, not injected |
| E-020 | observed | No `CONTRIBUTING.md` in repository root |
| E-021 | observed | No git tags; no `CHANGELOG.md`; no release workflow |

---

## 18. Validation Commands and Results

All commands executed in an isolated temporary home directory (`mktemp -d`) with real `HOME`, `XDG_DATA_HOME`, and `XDG_CONFIG_HOME` overridden. No real dotfiles were read or modified.

```bash
# Environment setup
ISOLATED_HOME=$(mktemp -d)
XDG_DATA_HOME="${ISOLATED_HOME}/.local/share"
XDG_CONFIG_HOME="${ISOLATED_HOME}/.config"
XDG_CACHE_HOME="${ISOLATED_HOME}/.cache"
XDG_STATE_HOME="${ISOLATED_HOME}/.local/state"

# Static checks on install.sh
bash -n install.sh                                          # exit 0  ✓
shellcheck --severity=style \
  --exclude=SC1090,SC1091,SC2034,SC2317 install.sh         # exit 0  ✓
shfmt -d install.sh                                         # exit 0  ✓

# Functional tests
env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --help                                       # exit 0  ✓ (help printed)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --version                                    # exit 0  ✓ (SHA printed)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --bogus                                      # exit 64 ✓ (unknown option)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --dry-run                                    # exit 0  ✓ (plan printed, no files)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --status                                     # exit 0  ✓ (not installed reported)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --no-shell-hook                              # exit 0  ✓ (installed, no hooks)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --status                                     # exit 0  ✓ (installer-owned shown)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --no-shell-hook                              # exit 0  ✓ (idempotent)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --uninstall                                  # exit 0  ✓ (prefix removed)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --shell bash                                 # exit 0  ✓ (block in ~/.bashrc)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --shell bash                                 # exit 0  ✓ (idempotent, one block)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --environment-diff --no-shell-hook           # exit 0  ✓ (PATH diff shown)

env HOME="${ISOLATED_HOME}" XDG_DATA_HOME="${XDG_DATA_HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  ./install.sh --no-shell-hook \
  --prefix "${ISOLATED_HOME}/my mantle dir"                 # exit 0  ✓ (space in prefix)
```

**Unverified validations** (no Zsh/Fish/macOS in audit environment):

- `./install.sh --shell zsh` — Zsh not installed; not executed.
- `./install.sh --shell fish` — Fish not installed; not executed.
- `./install.sh --method symlink` — Not executed; code path inspected.
- macOS `.bash_profile` selection — Not executed; macOS unavailable.
- Rollback after injected failure — Not executed; no automated test.

---

## 19. Continuation Requirements

This report is marked **partial** due to the following missing validations:

| Missing validation | Blocking issue | Required to close |
|---|---|---|
| Zsh activation (Zsh not installed) | AUDIT-002 | Run ISSUE-02 tests with Zsh available |
| Fish activation (Fish not installed) | AUDIT-002 | Run ISSUE-02 tests with Fish available |
| macOS clean install | AUDIT-006 | Run on a real macOS runner |
| `--method symlink` | AUDIT-002 | Include in ISSUE-02 test suite |
| Rollback after injected failure | AUDIT-008 | Include in ISSUE-02 test suite |
| Full behavioral test suite (`bats`) | AUDIT-002 | Bats must be installed in CI and locally |

**To upgrade this report to `complete`:**

1. Install Bats, Zsh, and Fish in the audit environment.
2. Run `./tests/run.sh` and capture full output.
3. Run `install.sh` on a real macOS machine and capture output.
4. Address AUDIT-001 (shfmt failures) so the static job is green.
5. Add and pass ISSUE-02 installer tests.
6. Append observed results to Section 18 above.

---

*End of audit report. Report status: `partial`. Audited commit: `3ba37090c483034a5ecd249a099467ab4f1b9e6e`.*
