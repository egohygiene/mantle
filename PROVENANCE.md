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

Three additional first-party files outside that snapshot were reconciled from
the same Empathy revision. The source blobs remain recoverable in Empathy Git
history under its MIT license:

| Empathy source | Source Git blob | Mantle destination |
| --- | --- | --- |
| `.staging/.github/scripts/delete-gone-branches.sh` | `fed8f691ec2e4b7ad698d430ff9b8920261d38f3` | `bin/git-delete-gone-branches` |
| `.staging/devenvironment/workstation/shared/shell/.bash_logout` | `88161704eae81d4c012f35e384873f3ef9e1278b` | `config/session/bash_logout` |
| `.staging/devenvironment/workstation/shared/shell/.hushlogin` | `1237801c72f7efa91bcd25cf1a2f6ac347f226cf` | `config/session/hushlogin` |

The Git helper was rewritten to keep fetch and deletion explicit, preserve
unmerged and checked-out branches, and support stock Bash 3.2. Session defaults
remain inert examples; Mantle never installs or sources them automatically.
Empathy records the exact-source removal approvals separately from its snapshot
inventory.

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


## Current-v1 release contract consumers

The release declaration and source workflow consume these immutable interfaces;
no upstream executable implementation is copied into Mantle:

- Aether `egohygiene.repository-release/v1`, source commit
  `8a2a3d08f3aa9da3847bd5277843506ab855192e`,
  `catalog/schemas/aether.repository-release.v1.schema.json`, SHA-256
  `8431ea7651336aa7695aee5b9aedce536b1e7c76c3cb15927f64a6206f9cc1f5`.
- Hygiene `egohygiene.repository-release-policy/v1`, source commit
  `28f9d6c7519d820644572634ba4476614f418d83`,
  `catalog/repository-release-policy.json`, SHA-256
  `20030513c311416c5130a15af897590892025b55cfd79d210be362d47748063f`.
  Version `1.0.0-alpha.1` remains proposed. Neither owner source is represented
  as a published release; their compatible selected bytes are validated by
  the independently qualified current-v1 EgoLint consumer.
- Published Relay v1.5.0, peeled commit
  `1eada5142f7fc7da7862f335589e3b8f5884ffaf`, supplies
  `.github/workflows/semantic-release.yml` and its `binary` release profile.
  This version does not expose `release-name`; its outer archive is
  `binary-vMAJOR.MINOR.PATCH.tar.gz`. Relay owns immutable publication and
  durable profile evidence, while Mantle owns source packaging and genuine
  signature/attestation production. Its generic inventory validation does not
  establish cryptographic verification.

These first-party source contracts are MIT-licensed under their respective
repository license notices. New Mantle preparation/evidence code is first-party
implementation within the existing release-tooling layer. Source-file SPDX
inventory reports checksums and `NOASSERTION` license conclusions; it does not
relicense artwork or certify optional host/runtime dependencies. Original
Identity and Incompris assets remain unchanged.
