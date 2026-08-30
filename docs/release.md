# Mantle release and recovery guide

Mantle releases are source distributions. A release is pinned by its exact
semantic version, checksummed, signed with GitHub Actions OIDC through Sigstore,
and accompanied by GitHub build provenance. Mantle does not install itself by
executing a mutable remote script.

## Supported environments

| Environment | Support level | Activation path | Notes |
| --- | --- | --- | --- |
| Bash 3.2+ | Supported | Installer-managed block in the user startup file or `source ".shellrc"` | The installer remains compatible with macOS's stock Bash. |
| Zsh | Supported | Installer-managed block in `"$HOME/.zshrc"` or `source ".shellrc"` | No global Zsh options are changed. |
| Fish | Supported | Installer-managed `"$XDG_CONFIG_HOME/fish/conf.d/mantle.fish"` | Fish uses its native runtime and never sources Bash files. |
| Linux and WSL | Supported | `platforms/linux/runtime.sh` | Covered by the Linux test job. |
| macOS | Supported | `platforms/darwin/runtime.sh` | Covered by the macOS test job. |
| MSYS2 and Git Bash | Windows-compatible | `platforms/windows/runtime.sh` | Native PowerShell is intentionally out of scope. |
| Devcontainers and CI | Supported non-interactively | `--no-shell-hook` | No startup file needs to be changed. |

Activation is additive: Mantle writes only its marked block or its own Fish
fragment. It never replaces a system shell, calls `chsh`, changes shell
preferences, runs with elevated privilege, or contacts the network while a
shell starts.

## Verify and install a pinned release

Choose the exact release version without the leading `v` tag prefix.

```sh
export MANTLE_VERSION="0.1.0"
curl --fail --location --remote-name "https://github.com/egohygiene/mantle/releases/download/v${MANTLE_VERSION}/mantle-${MANTLE_VERSION}.tar.gz"
curl --fail --location --remote-name "https://github.com/egohygiene/mantle/releases/download/v${MANTLE_VERSION}/mantle-${MANTLE_VERSION}.tar.gz.sigstore.json"
curl --fail --location --remote-name "https://github.com/egohygiene/mantle/releases/download/v${MANTLE_VERSION}/SHA256SUMS"
sha256sum --check "SHA256SUMS"
tar -xzf "mantle-${MANTLE_VERSION}.tar.gz"
"./mantle-${MANTLE_VERSION}/install.sh" --pin "${MANTLE_VERSION}" --shell bash
```

On macOS, replace the checksum command with:

```sh
shasum -a 256 -c "SHA256SUMS"
```

The `--pin` check makes the installer fail if the release archive's embedded
`VERSION` does not exactly match the requested version. The default prefix is
`"$XDG_DATA_HOME/mantle"`, or `"$HOME/.local/share/mantle"` when
`XDG_DATA_HOME` is unset. Choose an explicit user-owned prefix when needed:

```sh
"./mantle-${MANTLE_VERSION}/install.sh" \
  --pin "${MANTLE_VERSION}" \
  --prefix "$HOME/.local/share/mantle" \
  --shell all
```

## Verify the signature and provenance

The release workflow signs the archive with a keyless Sigstore certificate
bound to this repository's `release.yml` workflow and tag. After installing
Cosign, verify the downloaded archive with:

```sh
cosign verify-blob \
  --bundle "mantle-${MANTLE_VERSION}.tar.gz.sigstore.json" \
  --certificate-identity "https://github.com/egohygiene/mantle/.github/workflows/release.yml@refs/tags/v${MANTLE_VERSION}" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "mantle-${MANTLE_VERSION}.tar.gz"
```

GitHub also stores a signed build provenance attestation for each release
archive. If the GitHub CLI is available, verify it with:

```sh
gh attestation verify "mantle-${MANTLE_VERSION}.tar.gz" --repo "egohygiene/mantle"
```

Checksum verification detects download corruption; the Sigstore bundle and
GitHub attestation establish the release workflow identity and source
provenance. Perform all three checks before deploying a release to Realm.

## Lifecycle commands

A default copy installation contains its own lifecycle entrypoint, so diagnostics
and recovery remain available after the extracted release directory is removed.
`--method symlink` is a development mode and intentionally keeps the source
directory as a runtime dependency.

```sh
export MANTLE_PREFIX="$HOME/.local/share/mantle"
"${MANTLE_PREFIX}/install.sh" --status --prefix "${MANTLE_PREFIX}"
"${MANTLE_PREFIX}/install.sh" --doctor --prefix "${MANTLE_PREFIX}"
"${MANTLE_PREFIX}/install.sh" --disable --prefix "${MANTLE_PREFIX}" --shell all
"${MANTLE_PREFIX}/install.sh" --enable --prefix "${MANTLE_PREFIX}" --shell bash
"${MANTLE_PREFIX}/install.sh" --uninstall --prefix "${MANTLE_PREFIX}" --shell all
```

- `--doctor` checks the installed payload, the recorded version, CLI dispatch,
  and isolated Bash/Zsh/Fish bootstrap where those shells are available.
- `--disable` removes only Mantle-managed activation hooks and leaves the
  installed prefix intact.
- `--enable` restores selected managed hooks without reinstalling the payload.
- `--uninstall` removes only an installer-owned prefix and Mantle-managed hooks.
  Existing Bash and Zsh startup files are preserved; their first pre-install
  copy is retained as a sibling `".mantle.bak"` file for manual review.

If a Fish activation path already contains an unmanaged file or symlink, the
installer fails closed instead of replacing or deleting it.

## Pinned updates and rollback

Download and verify the next release exactly as in the installation section,
then run its installer against the existing prefix. Updates require `--pin`,
only operate on installer-owned destinations, preserve the existing copy or
symlink method by default, and atomically restore the previous prefix if
publication fails. They leave shell hooks unchanged.

```sh
export MANTLE_VERSION="0.1.1"
"./mantle-${MANTLE_VERSION}/install.sh" \
  --update \
  --pin "${MANTLE_VERSION}" \
  --prefix "$HOME/.local/share/mantle"
"$HOME/.local/share/mantle/install.sh" --doctor --prefix "$HOME/.local/share/mantle"
```

To roll back, download, verify, and run `--update --pin` from the earlier
release archive instead. No default-branch checkout or mutable release lookup
is required.

## Devcontainers and non-interactive environments

Avoid persistent shell hooks in CI and containers. Install the exact release
into a container-local prefix and source it only in processes that need it.

```sh
"./mantle-${MANTLE_VERSION}/install.sh" \
  --pin "${MANTLE_VERSION}" \
  --prefix "/opt/mantle" \
  --no-shell-hook
source "/opt/mantle/.shellrc"
mantle doctor --quiet
```

The runtime distinguishes interactive and non-interactive shells. Aliases and
history policies load only in interactive sessions; non-interactive commands
receive the required runtime baseline without changing the invoking shell.

## Publication and Realm consumption

A `v*` tag runs the release workflow. It builds a deterministic source archive,
exercises the isolated lifecycle, emits `SHA256SUMS`, creates a keyless Sigstore
bundle, stores GitHub provenance, and publishes the GitHub release. When the
GitHub release UI creates the tag and release together, the workflow uploads and
replaces only the three generated release assets. For a tag without an existing
release, the workflow creates the release. This makes publication retryable
without creating duplicate releases. Pre-release versions containing a hyphen
are published as GitHub pre-releases.

Realm must consume the exact versioned archive and retain its checksum,
Sigstore bundle, and attestation verification result as deployment evidence.
It must not consume Mantle from a mutable branch or an unverified tarball.
