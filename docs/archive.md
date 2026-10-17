# Project archives

`mantle archive` creates a filtered source snapshot from the files currently on
disk. Preview the selection, review any exceptions, then choose an explicit
destination. Python 3.9+ is required; a normal Git working repository also needs
Git for tracked and ignored state. Help and command discovery need neither.

```sh
mantle archive . --dry-run
mantle archive . --dry-run --json
mantle archive . --dry-run --output "../project.tar.gz"
mantle archive . --output "../project.tar.gz" --reproducible
mantle archive . --dry-run --include "dist/example.js"
```

The source defaults to the physical current directory. Use `--` before a source
path beginning with `-`. Output is always a gzip-compressed tar archive with one
top-level `project/` directory. The output's parent directory must already exist;
existing destinations are never overwritten. Dry runs create no files or
directories, including temporary archives.

## Selection rules

At a normal repository root, Git selects tracked files and untracked files
allowed by the repository's ignore rules. Tracked files still pass Mantle's
common-file filters: committing a private key does not automatically include it
in an archive. Missing tracked files are absent from this working-file snapshot.
Git history and LFS payloads are not fetched; an on-disk LFS pointer remains a
pointer.

Folders without their own `.git` use the built-in filesystem rules. An arbitrary
subdirectory uses that same filesystem mode; select the repository root to use
its Git rules. A detected Git repository requires a working Git executable;
missing Git or a failed Git query stops creation rather than weakening the
selection rules. Linked worktrees, redirected/shared Git metadata, and layouts
outside the supported local contract produce explicit failures.

Git queries are local, with an explicit working tree and Git directory. Mantle
ignores ambient Git redirection and personal/system Git configuration, disables
hooks, filesystem-monitor helpers, optional locks, and lazy object fetching,
and refuses unsupported metadata indirection. Repository ignore files remain
part of the selection contract; global personal ignore rules do not.
Git configuration includes, worktree-specific configuration, partial clones,
and sparse layouts are outside this initial supported contract.

The following built-in filters apply case-insensitively in both modes:

| Category | Excluded names |
| --- | --- |
| Dependencies | `node_modules`, `.venv`, `venv`, `vendor` directories |
| Caches | `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `.cache`, `.tox`, `.nox` directories |
| Generated output | `build`, `dist`, `target`, `.next`, `.nuxt`, `coverage` directories |
| Credential directories | `.ssh`, `.aws`, `.azure`, `.gnupg`, `.kube`, `.docker` |
| Environment files | `.env` and `.env.*`, except names ending in `.example`, `.sample`, `.template`, or `.defaults` |
| Keys and credential files | `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519`, `.netrc`, `_netrc`, `.npmrc`, `.pypirc`, `credentials.json`, `secrets.json`, `secrets.yaml`, `secrets.yml`, `service-account.json`, `service_account.json` |

Public-key `.pub` files, `.dockerignore`, lockfiles, and ordinary source
directories such as `src`, `bin`, `lib`, and `public` are eligible when the Git
rules also permit them. Filename rules cannot certify that arbitrary source
contents are free of secrets; the manifest makes the selected paths reviewable.

## Explicit exceptions and boundaries

Repeat `--include RELATIVE_FILE` to include a specific regular file otherwise
excluded by a common filter or Git ignore rule. Paths are exact, source-relative
filenames. Directory and wildcard overrides are unsupported. A requested
exception must exist and be eligible for safe reading; failed exceptions stop
archive creation.

Exceptions cannot bypass `.git` metadata, nested-repository, symlink, special-file,
filesystem, output-file, or archive-path boundaries. Scans do not follow links,
read devices/FIFOs, cross onto another device, or descend into nested repositories.
Symlink source paths and symlink output-parent components are refused, including
paths that try to hide a link behind `..`. Use a physical path instead.

Archive member names remain beneath `project/`. Absolute names, traversal
components, and backslash/drive escapes are rejected. Hard-linked source paths
become independent regular archive entries; archive members cannot escape by
being interpreted as hardlinks or symlinks.

An output inside the source is excluded from selection, along with aliases to
an existing output inode. Its temporary file is created only after selection.
Publication uses a new destination name without replacing an existing file;
failures before publication remove only the command's owned temporary file.
The published archive is private to its owner (`0600`).
Unreadable or changed selected files abort creation. Dry-run manifests describe
the observed selection; a later run observes the filesystem again.

The implementation requires Unix directory descriptors and no-follow operations
available on Linux and macOS. Unsupported runtimes, including native Windows
Python, fail explicitly. Destination filesystems must support the command's
atomic, no-overwrite publication operation. Inspection and copying use live
filesystem observations rather than an atomic source snapshot.

## Reproducible mode

`--reproducible` sorts entries, sets tar and gzip timestamps to zero, uses empty
owner/group names with numeric IDs zero, and normalizes directories to `0755`
and regular files to `0644` or `0755` according to their executable bit. The
gzip header contains no original filename. With the same selected paths,
contents, executable bits, and compression implementation, archive bytes and
the reported SHA-256 stay identical across source timestamp changes.

## Manifest and exit statuses

Human output escapes filenames and reports the same selection as `--json`.
The JSON schema is `egohygiene.mantle.archive/v1`:

| Field | Meaning |
| --- | --- |
| `path`, `output` | Absolute source and destination paths; destination is `null` when omitted for a dry run. |
| `selection_mode` | `git` or `filesystem`. |
| `dry_run`, `reproducible` | Requested operation and metadata policy. |
| `complete` | Whether planning or archive creation completed successfully. |
| `included` | Source-relative `path`, `size_bytes`, and selection `reason` for each file. |
| `excluded` | Source-relative `path` and exclusion `reason`; a directory entry covers its excluded subtree. |
| `warnings` | Failure records with `code`, `path`, and `message`. |
| `totals` | Selected file count in `files` and apparent bytes in `bytes`. |
| `sha256` | Published archive digest, or `null` for a preview/failed creation. |

Normal exclusions are visible in the manifest. Warnings set `complete: false`;
planning and copying failures prevent publication. If cleanup fails after
publication, the report retains the published archive's digest alongside the
failure. Usage and interpreter failures produce diagnostics; Git selection
failures retain a manifest with unverified candidate paths.

| Exit status | Meaning |
| --- | --- |
| `0` | Preview or archive creation completed. |
| `1` | Unsafe/inaccessible/changed input, invalid destination, failed Git query, or creation failure. |
| `64` | Invalid arguments, including creation without `--output`. |
| `69` | Python is unavailable/too old, or a Git repository cannot be queried because Git is unavailable. |

`tests/integration/archive.bats` verifies selection, overrides, safe member
names, deterministic archives, no-overwrite behavior, and failure cleanup with
temporary local fixtures. The existing integration CI jobs run it on Linux and
macOS.
