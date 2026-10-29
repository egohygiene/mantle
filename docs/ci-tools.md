# Verified CI validation tools

[`config/ci-tools.lock.tsv`](../config/ci-tools.lock.tsv) declares the identities,
artifact URLs, and SHA-256 digests used by Mantle's test and HLS workflows.
[`scripts/ci/setup-tools.sh`](../scripts/ci/setup-tools.sh) downloads into a private
temporary directory and verifies the selected artifact before extraction,
installation, or execution. A missing artifact or wrong digest fails with the
tool identity and an actionable diagnostic; it never falls back to an unchecked
download. Temporary downloads are removed when the helper exits.

The helper reuses Mantle's download and checksum libraries without activating
the shell runtime. It targets Bash 3.2 and uses the existing portable SHA-256
selection (`sha256sum`, `shasum`, or OpenSSL). It requires an explicit absolute,
writable installation prefix and never invokes `sudo` or changes `PATH` itself.
If a later requested tool fails, tools already installed by that invocation may
remain in the prefix; setup is not a transaction across multiple tools.

## Reviewed identities and provenance

| Tool | Identity | Artifact and digest evidence |
| --- | --- | --- |
| Bats Core | `1.11.0` | One source archive and one recorded digest for Linux and macOS. The digest was calculated from the downloaded archive, with its layout and installer reviewed. This is a reviewed content pin, not a publisher-signed checksum. |
| shfmt | `3.8.0` | Separate Linux/macOS AMD64/ARM64 binaries. Digests come from the upstream release's [`sha256sums.txt`](https://github.com/mvdan/sh/releases/download/v3.8.0/sha256sums.txt). |
| shdoc | `52917b2f3471fe77c745ede115494d2d5c9168d1` | The raw `shdoc` file at the full commit, with its digest compared to the Git source. This is the same commit selected by the existing product installer lock. |

The initial review date is **2026-10-29**. Exact URLs and full digests are in the
lockfile. The shdoc commit is deliberately independent of the upstream moving
default branch. Its script uses `/usr/bin/gawk`, so the current shdoc CI mapping
is Linux only; GNU Awk remains a required host-managed prerequisite. Bats uses
the same platform-independent source archive on each supported host. shfmt
selects its native binary by OS and architecture. Unknown or unlisted mappings
fail instead of guessing an artifact.

These tools remain external dependencies under their upstream licenses. Mantle
does not vendor their implementation or relicense downloaded artifacts.

The CI lock is separate from [`config/installers.lock.tsv`](../config/installers.lock.tsv):
validation-tool selection does not change the versions installed by product
commands. Third-party Actions keep their existing full-SHA pins.

## Local setup and validation

From the repository root, install the reviewed tools into an owned temporary
prefix on Linux:

```sh
MANTLE_CI_PREFIX="$(mktemp -d "/tmp/mantle-ci-local.XXXXXXXX")"
/bin/bash ./scripts/ci/setup-tools.sh --prefix "${MANTLE_CI_PREFIX}" bats shfmt shdoc
export PATH="${MANTLE_CI_PREFIX}/bin:${PATH}"
./tests/run.sh tests/integration/ci-tools.bats
./tests/run.sh --strict static
```

Install host prerequisites through the host's package manager when needed.
For strict Linux static validation these include ShellCheck, Zsh, Fish, and
GNU Awk. The helper does not install them. On macOS, request `bats shfmt` rather
than `shdoc`; the native macOS workflow only needs Bats from this helper.

The fixture suite uses isolated prefixes, controlled downloads and synthetic
payloads. It checks successful acquisition and rejection paths without real
network requests or privileged changes. The existing runner still owns strict
versus local validation: missing strict prerequisites remain failures, while
local optional-tool skips remain visible.

APT, Homebrew, runner-provided utilities, shells, and dedicated HLS media tools
are **host-managed**. Their package versions and transitive dependencies are
not locked by this file. Artifact verification does not claim a universal OS
package lock, publisher authenticity, or native-platform qualification.

Linux workflows can be exercised later with `act` using the same setup helper.
A container run does not establish native macOS behavior. Hosted Actions and
native macOS qualification are deferred to the later validation sweep; source
changes and local fixtures must not be recorded as those jobs having passed.

## Refresh procedure and ownership

Mantle maintainers own updates through a reviewed pull request:

1. Select the intended release or full commit and inspect upstream changes,
   artifact names, platform support, and installation requirements.
2. Fetch the candidate over HTTPS into a temporary directory. Compare its
   digest with published upstream checksums where available. For artifacts
   without published checksums, review their source or archive contents and
   record that limitation. For shdoc, compare the raw file with the file at the
   selected Git commit.
3. Update the identity, URL, platform mapping, and digest together in the CI
   lock. Keep Linux and macOS Bats on the same declared version and archive.
   Update this provenance record if the acquisition or trust boundary changes.
4. Run the focused fixture suite, the affected local checks, and real setup in
   a disposable prefix. Verify that a deliberately wrong digest and an
   unavailable artifact still fail before execution. Qualify affected native
   and hosted jobs when those runners are available, recording actual results.
5. Review the diff and evidence before merging. An unexpected checksum change
   is an investigation trigger, not permission to replace the expected value.

`--lockfile TRUSTED_TSV` explicitly selects an alternative trusted declaration
for fixture tests or reviewed experiments. It is parsed as literal data and
never evaluated as shell code, but its URLs and digests still authorize what
gets installed. Do not use an unreviewed lockfile to bypass a failed pin.
