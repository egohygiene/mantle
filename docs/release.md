# Mantle release and recovery guide

Mantle defines portable source distributions. This source candidate prepares a
manual release path; no published Mantle release or current signature is claimed.
A future approved release must be pinned by its exact semantic version,
checksummed, signed with GitHub Actions OIDC through Sigstore, and accompanied
by GitHub build provenance. Mantle does not install itself by
executing a mutable remote script.

## Supported environments

| Environment | Support level | Activation path | Notes |
| --- | --- | --- | --- |
| Bash 3.2+ | Supported | Installer-managed block in the user startup file or `source ".shellrc"` | The installer remains compatible with macOS's stock Bash. |
| Zsh | Supported | Installer-managed block in `"$HOME/.zshrc"` or `source ".shellrc"` | No global Zsh options are changed. |
| Fish | Supported | Installer-managed `"$XDG_CONFIG_HOME/fish/conf.d/mantle.fish"` | Fish uses its native runtime and never sources Bash files. |
| Linux and WSL | Supported | `platforms/linux/runtime.sh` | Covered by the Linux test job. |
| macOS | Supported | `platforms/darwin/runtime.sh` | Covered by the macOS test job. |
| MSYS2 and Git Bash | Experimental | `platforms/windows/runtime.sh` | Native PowerShell is intentionally out of scope. |
| Devcontainers and CI | Supported non-interactively | `--no-shell-hook` | No startup file needs to be changed. |

Activation is additive: Mantle writes only its marked block or its own Fish
fragment. It never replaces a system shell, calls `chsh`, changes shell
preferences, runs with elevated privilege, or contacts the network while a
shell starts.

## Verify and install a pinned release

Choose the exact release version without the leading `v` tag prefix.

```sh
export MANTLE_VERSION="0.1.0"
curl --fail --location --remote-name "https://github.com/egohygiene/mantle/releases/download/v${MANTLE_VERSION}/binary-v${MANTLE_VERSION}.tar.gz"
curl --fail --location --remote-name "https://github.com/egohygiene/mantle/releases/download/v${MANTLE_VERSION}/release-asset.sha256"
curl --fail --location --remote-name "https://github.com/egohygiene/mantle/releases/download/v${MANTLE_VERSION}/release-evidence.json"
sha256sum --check "release-asset.sha256"
mkdir "mantle-release-${MANTLE_VERSION}"
tar -xzf "binary-v${MANTLE_VERSION}.tar.gz" --directory "mantle-release-${MANTLE_VERSION}"
cd "mantle-release-${MANTLE_VERSION}"
sha256sum --check "SHA256SUMS"
```

On macOS, replace the checksum command with:

```sh
shasum -a 256 -c "release-asset.sha256"
# After extracting the outer bundle:
shasum -a 256 -c "SHA256SUMS"
```

## Verify the signature and provenance

The release workflow signs the archive with a keyless Sigstore certificate
bound to this repository's manually dispatched `release.yml` on `main`; the
archive, attestation and Relay evidence separately bind its exact source revision. After installing
Cosign, verify the downloaded archive with:

```sh
cosign verify-blob \
  --bundle "mantle-${MANTLE_VERSION}.tar.gz.sigstore.json" \
  --certificate-identity "https://github.com/egohygiene/mantle/.github/workflows/release.yml@refs/heads/main" \
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
provenance. Perform all three checks before extracting and installing the inner
source archive, then retain the verified receipts for deployment to Realm.

```sh
tar -xzf "mantle-${MANTLE_VERSION}.tar.gz"
"./mantle-${MANTLE_VERSION}/install.sh" --pin "${MANTLE_VERSION}" --shell bash
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

## Semantic version policy

The sole release authority is the reviewed immutable `vMAJOR.MINOR.PATCH` Git
tag declared in [.egohygiene/release.json](../.egohygiene/release.json). The
source `VERSION` remains `0.1.0-dev` for development compatibility; packaging
embeds the selected tag's version into the archive as derived output. Installer
`--pin` continues to compare that embedded `VERSION`, never the optional receipt.
Current-v1 Relay publication accepts stable versions only; this change does not
claim prerelease or build-metadata publication support.

Before 1.0, incompatible supported shell, CLI, configuration, installer ownership,
activation-hook, pin or rollback behavior requires a reviewed minor bump and an
explicit **Breaking changes** changelog entry. Compatible additions use a minor
bump; compatible corrections use a patch bump. At 1.0 and later, incompatible
supported interfaces require a major bump. Dropping Bash 3.2 or a supported
platform is a compatibility change. Deprecations identify their replacement and
planned removal horizon; later removal is reviewed rather than hidden in a patch.
Conventional Commits recommend bumps; they never select a version or publish.

The initial changelog has only `Unreleased`; development history is not invented
as a prior release. Preparation prints a reviewable promotion patch with an
explicit version/date. Review and commit that patch before verification.

## Local preparation and manual publication

The four Task handoffs are declared in `Taskfile.yml`:

- `release:plan`: inspect an exact `VERSION=v0.1.0` proposal without mutation.
- `release:prepare`: also supply `RELEASE_DATE=YYYY-MM-DD`; print a changelog patch for review, without applying it.
- `release:verify`: supply the prepared version and `ARCHIVE`; check committed local source and exercise the isolated install lifecycle.
- `release:publish`: hand off to the literal manual GitHub workflow and its required input prompts. It does not publish, create tags or upload assets locally.

The corresponding on-demand Python helper can be inspected or invoked directly.
Local preparation does not authenticate the current remote default branch or
create a signature. None of these tools runs during shell initialization.

The release workflow accepts only an explicit maintainer approval, stable tag,
and full reviewed current-`main` source revision. It requires a successful manual
Test Suite qualification run for that same `main` revision, with successful
Linux, native macOS and static jobs. `test.yml` now permits that separate manual
qualification; no hosted job is claimed to have run for this source candidate.
An ordinary push, tag or pull request never invokes release publication.

The producer checks the clean source/changelog, packages without overwriting a
local archive, exercises installation, creates and verifies the actual Cosign
signature, obtains GitHub build attestation, and writes complete source checksums
and a source-file SPDX inventory. External shell/media tools are not bundled or
certified by that inventory. Failure stops the bundle upload and Relay handoff;
bounded producer outcomes are retained independently of unrestricted logs.

The publisher calls **published Relay v1.5.0**, immutable commit
`1eada5142f7fc7da7862f335589e3b8f5884ffaf`, with its `binary` profile. That
version has no `release-name` input. Its release asset is an outer
`binary-vMAJOR.MINOR.PATCH.tar.gz` containing the original
`mantle-MAJOR.MINOR.PATCH.tar.gz`, signature/attestation bundles,
`provenance.json`, `sbom.spdx.json`, `signature.json`, `qualification.json` and
complete `SHA256SUMS`. `release-asset.sha256` and `release-evidence.json` bind
the outer artifact. Generic Relay profile validation checks inventory and bytes;
it does not cryptographically verify status JSON. Actual producer signing and
verification remain separate mandatory workflow steps. Local unsigned fixtures
record signature/attestation unavailable and prove bundle mechanics only.

Relay verifies current-main identity, the promoted changelog and tag availability,
and creates or resumes only an identical immutable release. A repeated build may
produce a different keyless signature and therefore fail an identical-byte resume;
retain the exact reviewed bundle for recovery instead of replacing assets.
No tag or release asset is ever force-updated or uploaded with overwrite flags.
Correct defects by retaining the historical release, reverting and preparing a
reviewed successor; consumer rollback uses an independently verified prior archive
and its unchanged `--update --pin` interface. Homebrew and other registries remain
optional external adapters.

The current-v1 Aether schema source is `8a2a3d08f3aa9da3847bd5277843506ab855192e`;
Hygiene's profile source is `28f9d6c7519d820644572634ba4476614f418d83`, still
`proposed`. Neither has a published release. This migration does not promote
those authorities or adopt the successor Hygiene #65 policy. Full acceptance
retains accepted compatible EgoLint #29 producer evidence, supported-platform
qualification, actual signing/attestation and separate publication approval.

## Installation receipts and Realm consumption

Release archives contain one generated `RELEASE-METADATA.json` naming the exact
tag, source revision, inner archive and release/evidence filenames. A copy install
retains that optional inert receipt; `install.sh --status` reports its location and
states that the installer did not authenticate it. Development or legacy installs
need no receipt, and doctor/startup never depends on it or parses it as shell.
Updating from a source without a receipt clears the old receipt; transaction
rollback restores the earlier installation and receipt together.

An archive cannot contain its own final checksum without self-reference.
Authenticate the archive externally using its Cosign bundle, attestation and
Relay checksum/evidence; an embedded receipt is context, not proof. Preserve the
verified external evidence alongside the installation's deployment record.
Realm must consume the exact reviewed release bundle, verify the inner source
archive before installation and retain source revision, checksum, signature and
attestation results. Mutable branches and unverified archives remain unsupported.
