# Installer assurance

Mantle resolves installer inputs through
[`config/installers.lock.tsv`](config/installers.lock.tsv). The registry records
the source, resolution policy, selected version or commit, and integrity signal
for each installer component. Inspect that contract without downloading or
installing anything:

```sh
mantle install --assurance
mantle install --assurance eza
mantle install --assurance linuxbrew
```

## Resolution and integrity

| Resolution class | Default selection | Integrity signal |
| --- | --- | --- |
| GitHub release | Exact version from the registry | Upstream release checksum where supported; otherwise an explicit verification opt-out is required. |
| Python, Ruby, or npm package | Exact package version from the registry | Package-manager transport and artifact validation. |
| Git source | Full 40-character commit ID | Git commit identity, rather than a moving branch or tag. |
| Remote installer script | Commit-specific URL | Registry-pinned SHA-256 for that exact script. |
| Native package | Version selected by the active system package manager | Package-manager repository metadata. |

`manager` records a host-managed boundary. Operating-system repositories differ
by distribution, release, architecture, configuration, and update state. The
registry does not invent a universal native-package lock or claim that two
different operating systems install identical artifacts.

An exact version and a checksum provide different evidence. Release checksums
check the artifact against the selected upstream metadata; they do not create
an independent author signature. Likewise, package-manager validation does not
mean Mantle vendors the package or has audited its implementation. Upstream
licenses remain applicable, as described in [PROVENANCE.md](PROVENANCE.md).

## Default and override behavior

- Omitting an installer-specific `--version` or `--ref` selects the checked-in
  lock rather than a live `latest`, `main`, `master`, or `HEAD` lookup.
- Well-known mutable selectors are rejected when explicitly supplied.
  Repository-source installers require a full 40-character hexadecimal commit
  ID; an arbitrary branch name or abbreviated ref is insufficient.
- A GitHub release installer without a supported upstream checksum refuses
  installation unless the caller explicitly supplies `--no-verify`. Dry runs
  remain available and identify the required opt-out. `explicit-opt-out` is an
  honest assurance classification, not verified provenance.
- The Linuxbrew default bootstrap URL and SHA-256 identify the same pinned
  script. An explicit `--installer-url` override must supply its own digest or
  the command's explicit unverified-installer opt-out; it does not inherit the
  default script's digest merely because argument parsing started with it.
- Explicit exact-version and full-commit overrides remain available for
  deliberate testing and upgrades. Supported dry runs distinguish registry
  defaults from explicit selections.

Flags and writable destinations remain installer-specific. Use the public
installer help before applying an override:

```sh
mantle install eza --help
mantle install eza --dry-run
mantle install shdoc --help
```

Installation is an explicit command action. Shell initialization does not
refresh locks, download packages, initialize package managers, or request
privilege. [The install runtime](lib/install/README.md) defines download,
archive, filesystem, and process-isolation boundaries.

## Update a lock

1. Verify the upstream release, package, or full commit against its authoritative
   source and inspect changes relevant to the installer.
2. Update the component's row in `config/installers.lock.tsv`. Keep the resolver
   and verification classification accurate.
3. For a remote script, update its exact URL/commit and SHA-256 together. Verify
   the bytes for that source rather than retaining an unrelated old digest.
4. Run the affected dry run, focused installer tests, registry contract tests,
   and the canonical suite.
5. Review lock/assurance changes separately from unrelated shell policy.

The contract suite checks installer coverage, duplicate component records,
mutable exact locks, full Git commit requirements, and agreement between
checksum declarations and reported assurance. Tests use controlled fixtures;
they do not prove that every upstream service is available or every package
works on every platform.

The registry governs installed tools. Verification of Mantle's own source
distribution, signatures, release provenance, installation lifecycle, and
rollback is a separate contract in [the release guide](docs/release.md).
