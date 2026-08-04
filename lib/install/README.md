# Mantle installer runtime

The source-only Bash runtime in `lib/install/` provides deterministic,
reusable installation primitives. Private installer implementations belong in
`libexec/mantle/installers/`; users invoke them through `mantle install`.

## Runtime layout

```text
lib/install/
├── README.md
├── runtime.sh
├── platform.sh
├── package-manager.sh
├── download.sh
├── checksum.sh
├── archive.sh
├── filesystem.sh
├── github.sh
├── native-package.sh
└── python-tool.sh
```

The runtime loads required core libraries and install capabilities
transactionally. Missing or failed dependencies leave
`MANTLE_INSTALL_RUNTIME_STATE=failed`, and a later source attempt can retry.

## Responsibility boundaries

- `platform.sh` maps Mantle's normalized OS and architecture values to upstream
  release naming.
- `package-manager.sh` detects an available native package manager without
  installing anything.
- `download.sh` performs HTTPS-first, retried, atomic downloads.
- `checksum.sh` calculates and verifies SHA-256 and SHA-512 digests.
- `archive.sh` validates member paths before extracting supported archives.
- `filesystem.sh` owns temporary workspaces and atomic executable placement.
- `github.sh` orchestrates declarative GitHub Releases installers.
- `native-package.sh` installs named packages through a supported host package
  manager without implicit privilege escalation.
- `python-tool.sh` installs Python command-line tools into isolated `uv` or
  `pipx` environments.

This layer does not choose workstation packages or provision environments.
Profiles and environment assembly belong to Realm or a higher-level Mantle
orchestrator.

## Security contract

- Downloads require HTTPS unless
  `MANTLE_INSTALL_ALLOW_INSECURE_DOWNLOADS=1` is explicitly set.
- Configured checksum assets fail closed when no matching digest is found.
- `--no-verify` is an explicit escape hatch and emits a warning.
- Archives are rejected when they contain absolute paths or parent traversal.
- Executables are staged and atomically moved into place.
- The runtime never invokes `sudo`; callers must select a writable install
  directory or arrange privilege outside Mantle.
- Temporary cleanup is restricted to directories created by this runtime.
- The GitHub workflow runs in a subshell, so its signal and exit traps cannot
  replace traps in the caller's shell.

## Thin-wrapper contract

A GitHub Releases installer sources `lib/install/runtime.sh`, declares metadata,
and delegates to `mantle_install_github_main`:

```bash
MANTLE_INSTALL_TOOL_NAME="example"
MANTLE_INSTALL_GITHUB_OWNER="example-org"
MANTLE_INSTALL_GITHUB_REPOSITORY="example"
MANTLE_INSTALL_ASSET_TEMPLATE="example-{{version}}-{{platform}}-{{arch}}.tar.gz"
MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE="example-{{version}}/example"
MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE="checksums.txt"
MANTLE_INSTALL_VERIFY_ARGUMENTS=("--version")

mantle_install_github_main "$@"
```

Required metadata:

- `MANTLE_INSTALL_TOOL_NAME`
- `MANTLE_INSTALL_GITHUB_OWNER`
- `MANTLE_INSTALL_GITHUB_REPOSITORY`
- `MANTLE_INSTALL_ASSET_TEMPLATE`

Common optional metadata:

- `MANTLE_INSTALL_VERSION`
- `MANTLE_INSTALL_DIRECTORY`
- `MANTLE_INSTALL_TAG_TEMPLATE`
- `MANTLE_INSTALL_VERSION_PREFIX_TO_STRIP`
- `MANTLE_INSTALL_BINARY_NAME`
- `MANTLE_INSTALL_ARCHIVE_FORMAT`
- `MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE`
- `MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE`
- `MANTLE_INSTALL_CHECKSUM_ALGORITHM`
- `MANTLE_INSTALL_VERIFY_ARGUMENTS`
- platform and architecture mappings prefixed with `MANTLE_INSTALL_PLATFORM_`
  and `MANTLE_INSTALL_ARCH_`

`MANTLE_INSTALL_GITHUB_TOKEN` may be set for authenticated GitHub API requests;
`GITHUB_TOKEN` is used as a fallback.

## Shared command interface

Runtime-backed installers expose through the public CLI:

```text
mantle install TOOL --version VERSION
mantle install TOOL --install-dir DIRECTORY
mantle install TOOL --dry-run
mantle install TOOL --no-verify
mantle install TOOL --help
```

The default destination is `XDG_BIN_HOME`, then `$HOME/.local/bin`, and finally
`/usr/local/bin` only when no home directory is available.
