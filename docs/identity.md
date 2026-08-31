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
