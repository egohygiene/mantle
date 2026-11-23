# Mantle Brand Kit integration

Mantle owns its canonical brand intent beneath `.identity/`. Identity validates
and compiles that intent into `assets/identity/`; README, documentation,
release, and future site consumers read only the generated interface.

## Authority boundary

| Surface | Owner | Mutation authority |
| --- | --- | --- |
| `.identity/` | Mantle maintainers | Human-reviewed edits only |
| `assets/identity/` | `egohygiene/identity` projections | Pinned compiler and renderers |
| `evidence/repository-presentation.json` | Mantle | Explicit observed state; Identity never infers it |
| `vendor/hygiene/` | Hygiene snapshot | Replace only after reviewing a full commit and digest |
| README and downstream surfaces | Mantle | Consume generated files without redefining brand facts |

Generated output never becomes canonical source merely because it is committed.

## Pinned toolchain

- Core compiler and Brand Kit profiles: `egohygiene/identity@v1.0.0`.
- Source validator and repository-presentation renderer:
  `egohygiene/identity@3c2fd3141371b355628e81f66f63159f19d63338`.
- Repository-presentation policy:
  `egohygiene/hygiene@28f9d6c7519d820644572634ba4476614f418d83`,
  profile `1.0.0-alpha.1`, status `proposed`.

The post-v1 scripts are pinned by immutable commit and file digest until their
contracts ship in a later Identity release. The proposed Hygiene profile is
consumed without claiming that it is active policy or certification.

## Regeneration

From an Identity source checkout at the pinned commit:

```bash
python3 scripts/validate_identity.py \
  --repository-root "../mantle" \
  --format "human"

identity v1-generate --repository-root "../mantle"
identity v1-verify --repository-root "../mantle"

PYTHONPATH="scripts" python3 scripts/render_repository_presentation.py \
  --repository-root "../mantle" \
  --evidence "evidence/repository-presentation.json" \
  --output "assets/identity/repository-presentation"
```

Review canonical source changes separately from generated diffs. Never repair a
generated file by hand.

## Verification and drift

The Identity workflow downloads only immutable tool artifacts, verifies their
SHA-256 digests, validates `.identity/`, runs the released compiler verifier,
regenerates repository presentation into a temporary directory, and compares
that complete tree with the committed package.

Any mismatch blocks integration. Update the source, approval evidence, pinned
toolchain, and generated outputs together in one reviewable change.

## Upgrade and rollback

To upgrade, review the upstream Identity or Hygiene diff, change the immutable
version/commit and digest together, regenerate into a separate directory,
inspect the visual and machine-readable diffs, and publish only after human
review.

To roll back, restore the previous `.identity/`, `vendor/hygiene/`, evidence,
and `assets/identity/` set together, then rerun validation and verification.

## README reference and local deviations

The README selects the existing vendored Hygiene repository-presentation profile
`egohygiene.repository-presentation-profile/v1`, version `1.0.0-alpha.1`, from
[`28f9d6c7519d820644572634ba4476614f418d83`](https://github.com/egohygiene/hygiene/tree/28f9d6c7519d820644572634ba4476614f418d83).
The exact local input is
[`vendor/hygiene/repository-presentation-profile.v1.json`](../vendor/hygiene/repository-presentation-profile.v1.json),
SHA-256 `44e0881519350e6747723995939c79c6fb4659e38a74b2c32e409866e7a186ba`.
Its lifecycle remains **proposed**. This authored presentation does not activate
organization policy, certify Mantle or update existing dated conformance evidence.

Local presentation decisions for the issue51 refresh:

- Keep the already approved dark banner and meaningful alternative text; the
  title and purpose remain readable when images or networking are unavailable.
  Canonical Identity inputs, generated assets and original artwork are unchanged.
- Omit remote decorative/tool badges and the historical partial-conformance badge.
  The linked workflow and evidence retain their actual status; a badge is not
  substituted for current qualification.
- Keep a short landing page and relocate the former detailed feature, command,
  configuration and lifecycle sections to [the usage reference](usage.md).
  Feature-specific contracts remain authoritative and linked.
- Link the live execution tracker rather than maintaining a competing list of
  planned features. Preserve dated roadmap and audit evidence.
- State the missing private vulnerability-reporting channel explicitly; do not
  invent a security contact or organizational guarantee.

The profile's generated-region rules apply to automated composition. This
maintainer-authorized authored documentation change does not add an automatic
README rewriter or expand the Identity renderer's mutation authority.
