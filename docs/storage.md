# Storage inspection

`mantle storage` inspects local storage without changing files, installing tools,
or contacting remotes. It requires Python 3.9+. Help and command discovery work
without Python. GNU-specific
`du`, `df`, and `stat` options, `jq`, Git LFS, and disk-visualization tools are
not required.

The scanner uses Unix directory descriptors and no-follow operations supported
on Linux and macOS. Runtimes lacking those safety APIs, including native
Windows Python, return an `unsupported_platform` partial report instead of
falling back to an unsafe traversal.

## Commands

```sh
mantle storage disk
mantle storage directory "/path/to/project"
mantle storage large-files "/path/to/project" --min-size 10485760 --limit 10
mantle storage repo "/path/to/repository" --json
mantle storage objects "/path/to/repository"
```

Paths default to the current directory. Use `--` before a path beginning with
`-`. Options may follow the path. `--limit` and `--min-size` apply only to
`large-files`; they default to 20 results and 1,048,576 bytes respectively.
Sizes and thresholds use integer bytes, without locale-dependent parsing.

| Command | Measurement |
| --- | --- |
| `disk` | Total, used, and available capacity of the filesystem containing the target. |
| `directory` | Recursive file sizes and entry counts inside the target directory. |
| `large-files` | Regular files ranked by apparent size, descending, with a stable path tie-break. |
| `repo` | Working tree, local Git metadata, object storage, LFS cache, and LFS pointer declarations. |
| `objects` | Local loose objects, pack files, and other files in `.git/objects`. |

`repo` and `objects` require the repository root itself, with a normal `.git`
directory. Bare repositories, linked worktrees, and submodules whose `.git`
file redirects to another location are outside this command's scan boundary.
Object measurements describe files stored locally; they do not rank historical
blobs or claim to measure their uncompressed sizes. Pack indexes and other
sidecars are separate from `.pack` files.

## Accounting and boundaries

Apparent bytes measure regular-file lengths. Allocated bytes use the
filesystem's reported block allocation, so sparse files can have much larger
apparent sizes than allocated sizes. These values are observations, not an
estimate of how much a deletion would reclaim on compressed, shared, or
copy-on-write storage. Directory-entry overhead is excluded from byte totals.
Hard-linked regular files count once per scan.

Scans skip symlinks, special files, and other devices. Generic directory,
large-file, and working-tree scans also skip nested repositories; local Git
metadata is measured as a complete physical directory within its own boundary.
Generic `directory` and `large-files` scans include the target's own `.git`;
they skip repository roots nested beneath the target.
Repository working-tree accounting excludes `.git`; Git metadata and its LFS
cache are reported separately and overlap, so their totals should not be added
together. LFS pointer declarations describe content that may be absent locally;
declared payload sizes are never added to disk usage. No LFS payload is fetched.

A symlink target or symlink path component is refused. Use a physical path
instead; `pwd -P` identifies the current physical directory. The current
directory default uses its physical path. External object alternates and Git
metadata redirects are not traversed. Expected exclusions have counters or
warnings; failures to inspect requested storage produce an incomplete result.

Inspection is an observation of a changing filesystem, not an atomic snapshot.
Unreadable or vanished entries produce warnings instead of silent zero totals.
Run as the ordinary user whose storage you want to inspect; privilege elevation
is neither required nor performed.

## Output contract

Human output renders the same measurements as JSON, with byte labels and escaped
paths. Filenames containing newlines or terminal-control characters remain
single safe labels. Use `--json` for automation. Reports use this versioned
envelope:

```json
{
  "schema": "egohygiene.mantle.storage/v1",
  "command": "directory",
  "path": "/path/to/project",
  "complete": true,
  "data": {},
  "warnings": []
}
```

The `data` object contains the selected command's measurements:

| Command | Data fields |
| --- | --- |
| `disk` | `total_bytes`, `used_bytes`, `free_bytes` |
| `directory` | `apparent_bytes`, `allocated_bytes`, `files`, `directories`, `symlinks`, `hardlinks`, `sparse_files`, `special_files`, `skipped_mounts`, `skipped_repositories` |
| `large-files` | `limit`, `min_size_bytes`, `scanned_files`, `files` |
| `repo` | `worktree`, `git`, `objects`, `lfs` |
| `objects` | `loose`, `packs`, `other` |

Each large-file result has a relative `path`, `apparent_bytes`, and
`allocated_bytes`. Object groups have `count`, `apparent_bytes`, and
`allocated_bytes`. Repository `worktree`, `git`, and `lfs.cache` use the directory
statistics. `lfs.pointers` separates pointer `count` and `declared_bytes` from
local storage and supplies pointer details in `files`.
Pointer details are capped at 20 entries; `truncated` indicates that additional
pointers were counted. Missing filesystem allocation information is represented
by `allocated_bytes: null` and an incomplete report, never an apparent-size
substitute.

Warnings contain `code`, `path`, and `message`. Treat `complete: false` as a
partial observation even when some measurements are present. Dependency and
usage failures return diagnostics rather than a storage report.

| Exit status | Meaning |
| --- | --- |
| `0` | Requested inspection completed. |
| `1` | Incomplete inspection or inaccessible/unsafe target; JSON remains parseable. |
| `64` | Invalid command, option, or argument. |
| `69` | Required Python interpreter is unavailable or too old. |

## Validation

`tests/integration/storage.bats` exercises the public dispatcher with generated
large-file, sparse-file, hard-link, LFS, and permission fixtures. The same suite
runs on Linux and macOS through the existing integration CI jobs. Fixtures are
temporary and do not require network access or Git LFS.
