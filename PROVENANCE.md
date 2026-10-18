# Mantle provenance

Copyright 2026 Ego Hygiene

SPDX-License-Identifier: MIT

## Canonical source and lineage

[`egohygiene/mantle`](https://github.com/egohygiene/mantle) owns Mantle's reusable
shell runtime, CLI utilities, and installer implementation. Empathy owns the
golden repository baseline and integration evidence; its historical `mantle/`
directory is a migration source rather than a second permanent implementation.

Mantle's earlier standalone source was imported into Empathy in commit
[`e53f191b48c8e19a1ee8953032d36fb30cf42f76`](https://github.com/egohygiene/empathy/commit/e53f191b48c8e19a1ee8953032d36fb30cf42f76).
Independent work subsequently accumulated in both repositories. Consolidation
uses Empathy's immutable source snapshot
[`b344dcbbbd51397cb1e9b1afa6f289af856054f4`](https://github.com/egohygiene/empathy/tree/b344dcbbbd51397cb1e9b1afa6f289af856054f4/mantle)
and retains the standalone implementation's later behavior and contracts.
Git history and migration evidence identify which source was preserved,
adapted, or superseded; the import does not transfer ownership to Empathy.

The Empathy source's
[`PROVENANCE.md`](https://github.com/egohygiene/empathy/blob/b344dcbbbd51397cb1e9b1afa6f289af856054f4/mantle/PROVENANCE.md)
has SHA-256
`7c48e9e74d3a9ed90cb7b9e60b78db34833b8d76e310d0b1788de503fdbe5902`.
It records first-party Ego Hygiene code under MIT. The root [LICENSE](LICENSE)
preserves the same copyright and complete MIT permission notice. Retain source
copyright/SPDX notices when moving or adapting files.

Organization ownership and deletion gates remain recorded in Empathy's
[`ADR-0001`](https://github.com/egohygiene/empathy/blob/b344dcbbbd51397cb1e9b1afa6f289af856054f4/docs/decisions/ADR-0001-foundation-ownership.md)
and
[foundation ownership audit](https://github.com/egohygiene/empathy/blob/b344dcbbbd51397cb1e9b1afa6f289af856054f4/.audits/2026-08-20-foundation-ownership.md).
Those records are not replaced with retrospective Mantle ADRs.

## Third-party and generated-material boundaries

Mantle does not vendor the source of its shell, test, media, or installer tools.
The following references have distinct roles:

- Bats Core, ShellCheck, shfmt, shdoc, Bash, Zsh, Fish, Python, FFmpeg, and
  ffprobe are external execution or validation dependencies. Tests use synthetic
  media and controlled fixtures rather than importing a provider's media.
- Installer adapters identify upstream projects and fetch their packages or
  release artifacts when explicitly invoked. The fetched artifacts remain
  governed by upstream licenses; a Mantle adapter's MIT notice does not
  relicense an upstream tool.
- `config/fastfetch/fastfetch.jsonc` is Mantle configuration against the
  published Fastfetch schema. It is not a vendored Fastfetch implementation.
- `.identity/` contains canonical Mantle identity inputs. `assets/identity/`
  contains generated Identity packages, with pinned toolchain and regeneration
  instructions in [the Identity guide](docs/identity.md). `vendor/hygiene/`
  preserves the explicitly pinned policy snapshot, not arbitrary runtime code.
- The optional Incompris shell artwork is Alan's original material.
  [Its source record](assets/presentation/README.md) preserves the original
  commit, blob, source path, and SHA-256. It is separate from Mantle's generated
  Brand Kit. Preserve that record when renaming or relocating artwork.
- Historical audits describe their recorded source revision and execution
  environment. They are evidence, not current validation results or policy.

No additional third-party executable/library source or separate third-party
license notice was identified in the pinned Empathy `mantle/` tree. This is a
statement about that inspected source snapshot; future imports must be reviewed
and recorded explicitly.

## Import requirements

For any vendored, copied, generated-from, or substantially adapted material,
record:

1. The original project and canonical source URL.
2. The exact release or full commit, original path, and a content digest.
3. The upstream license and all required copyright and permission notices.
4. The destination paths, local changes, and relevant validation evidence.
5. The generator/version and reproducible command for generated output, or a
   clear explanation when faithful regeneration is unavailable.

Put required license texts and notices beside the imported material and add a
specific record here or in a linked migration record. Do not infer authorship,
license, or successful validation from a filename or package download URL.
Preserve recoverable source and record destination evidence before deleting a
historical copy. Release-archive verification is a separate contract described
in [the release guide](docs/release.md).
