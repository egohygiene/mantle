# Mantle v1 release readiness

Snapshot: 2026-11-23. `v1.0.0` is the proposed first stable release; publication
remains a separate approved handoff. Source checkouts retain `VERSION=0.1.0-dev`
and the declaration remains `unreleased`; archives derive their version from
an exact tag. Installer, XDG/Fish and verifier fixes were qualified together at
`d4b1acc8568f174d1f9523b118c8c733dc46e0db`.

The selected ChatGPT workspace failed to start. Executable evidence below comes
from actual free standard public GitHub runners, not local workspace execution.
Later source or documentation revisions require their own checks; final-head
results belong to [PR #54](https://github.com/egohygiene/mantle/pull/54).

## Exit criteria

| Gate | Current status | Required evidence before release |
| --- | --- | --- |
| Reviewed source | Installer, XDG/Fish and verifier source reviewed; combined candidate checks passed | Review the final release commit, including changelog promotion and the qualification receipts. |
| Linux | Passed on Ubuntu 22.04 x86_64 at the revision below | Retain strict validation, profile/catalog and temporary-HOME lifecycle results for the final reviewed source. |
| Native macOS | Passed on macOS 15.8.2 arm64 with stock Bash 3.2, Zsh and Fish at the revision below | Retain native temporary-HOME lifecycle/startup results for the final reviewed source. Intel Mac remains unqualified. |
| Hosted qualification | Pending | Successful manual Linux, native macOS and static jobs for the exact reviewed main revision, as required by the release workflow. Local runs do not satisfy this gate. |
| Release integrity | Unsigned candidate packaging and pinned install lifecycle passed on both platforms; matching archive bytes | Verify the promoted changelog and final source; obtain and verify actual signatures and build attestations. Unsigned mechanics do not authenticate a release. |
| Publication | Pending separate approval | Publish only the reviewed stable tag and verified bundle through the existing release boundary. |

Linux is the first runtime target; native macOS is required before describing the
candidate as ready for a Mac refresh. MSYS2/Git Bash remains experimental;
native PowerShell and universal portability are not promised by these checks.
See [release and recovery](release.md) and the live
[execution tracker](https://github.com/egohygiene/mantle/issues/45).

## Candidate qualification receipt

The [push Test Suite](https://github.com/egohygiene/mantle/actions/runs/45135956695)
and [PR Test Suite](https://github.com/egohygiene/mantle/actions/runs/45135963573)
completed successfully for candidate `d4b1acc8568f174d1f9523b118c8c733dc46e0db`.
Both Identity runs also passed. The push checkout provides the exact-source
package comparison; PR checkouts may use a synthetic merge revision.

- Linux: all 13 strict validation groups passed with zero failed/skipped groups.
  The 1,015 Bats cases contain 978 passes, 37 explicit skips and zero failures.
  Six profiles and 90 catalog commands validate; the isolated install smoke passes.
- macOS: all unit, integration, contract and CLI layers passed: 969 passes,
  46 explicit skips and zero failures across 1,015 cases. Five additional native
  startup runs passed all 32 cases each. The isolated install smoke passes.
  Platform: macOS 15.8.2 arm64, Bash 3.2.57, Zsh 5.9 and Fish 4.9.3.
- Both jobs packaged clean source as an unsigned `1.0.0` archive and passed its
  pinned install, status, doctor, enable/disable and uninstall lifecycle. Both
  archives have SHA-256
  `1672ccb67aa3b683eea31ded4b1ecbf2fc7283330d6f74a32b3511bc285c7c4f`.
  This hash identifies that candidate, not a published or later rebuilt release.

Optional skips do not qualify their missing platform/tool capabilities. Intel
Mac and Windows are not qualified by these runs. No real home-directory data,
startup preferences or applications were migrated. No package was uploaded,
tagged, signed, attested or published by these qualification jobs.

## Public CI fallback

The current public repository uses standard `ubuntu-22.04` and `macos-15`
runners for Test Suite. GitHub documents
[public standard-runner compute as free](https://docs.github.com/en/actions/reference/runners/github-hosted-runners#standard-github-hosted-runners-for-public-repositories).
Automatic push/PR runs upload no diagnostic artifacts and write no Actions
caches. Failure diagnostics require a manual `workflow_dispatch` with the
typed `upload-diagnostics` input explicitly enabled; its default is false and
opted-in artifacts retain for one day. Normal logs retain the check output.

Test Suite checkouts do not persist credentials into copied fixtures. Linux and
native macOS jobs report their source/platform/interpreters and run the isolated
install smoke. Linux installs the declared static tools and executes the complete
canonical strict runner once; macOS retains its native test layers. Before
packaging, both jobs verify the latest dated changelog proposal against the
exact checkout using the existing release-control helper. They package that
validated proposal as an unsigned, unpublished candidate (`1.0.0` for the first
stable preparation). They log the source revision and
archive SHA-256 and exercise the unpacked pinned install lifecycle through
`scripts/verify-release.sh`. The archive stays on runner-local temporary disk;
there is no package upload, signature, attestation, tag or publication. macOS
ensures Fish is installed before executing its native cases.

These runs qualify only the exact source, platform and available capabilities
they actually execute. A PR/branch result does not satisfy the unchanged release
requirement for a successful manual Test Suite run on the reviewed current
`main` revision, followed by release-integrity checks and publication approval.
The declaration remains `unreleased` and source `VERSION` stays `0.1.0-dev`.
A dated `1.0.0` changelog promotion prepares the first release while retaining
one `Unreleased` section; the heading alone does not establish publication.

## Local qualification commands

Run from the combined candidate checkout with the prerequisites in
[the test guide](../tests/README.md). Record the exact commit, OS, architecture,
shell/tool versions, failures and skips. These are instructions, not results.

On Linux:

```sh
git rev-parse HEAD
/bin/bash ./tests/run.sh --strict
/bin/bash ./tests/smoke/install.sh
./bin/mantle profiles validate
./bin/mantle catalog validate
```

On a real Mac, use the stock Bash for executable wrappers as well as the runner,
while keeping installed test tools reachable:

```sh
git rev-parse HEAD
sw_vers -productVersion
uname -m
/bin/bash --version
zsh --version
python3 --version
for attempt in 1 2 3 4 5; do
  PATH="/bin:/usr/bin:/usr/sbin:/sbin:${PATH}" \
    /bin/bash ./tests/run.sh tests/integration/startup.bats || exit "$?"
done
for suite in unit integration contract bin; do
  PATH="/bin:/usr/bin:/usr/sbin:/sbin:${PATH}" \
    /bin/bash ./tests/run.sh "${suite}" || exit "$?"
done
/bin/bash ./tests/smoke/install.sh
```

The integration fixtures isolate their HOME/XDG state. The install smoke creates
its own temporary HOME and prefix, installs twice, checks status and CLI dispatch,
then uninstalls without managing real startup files. Review the installer-specific
regressions for explicitly supplied `ZDOTDIR`, refused symlinks/nonregular files,
file modes, malformed markers, interrupted transactions and failed restoration.
Do not replace native results with Linux mocks or count optional skips as passes.
No real Mac installation, migration or whole-home cleanup is part of this plan.

## Selected installation and runtime boundaries

- Bash and Zsh source `.shellrc`; Fish sources its native
  `runtime/shells/fish/runtime.fish` after setting `MANTLE_ROOT`. Mantle configures
  an existing shell; it is not a replacement shell executable.
- Installer Zsh hooks use an explicitly supplied absolute `ZDOTDIR`, otherwise
  HOME. An explicitly supplied empty or relative value is rejected. The installer
  does not invent a HOME-level `.zshenv` migration. This follows
  [Zsh's startup-file lookup](https://zsh.sourceforge.io/Doc/Release/Files.html).
- Refuse symlink and nonregular Bash/Zsh hook paths before mutation; preserve
  existing file modes; fail closed on malformed managed markers. Disable/uninstall
  must leave unowned startup bytes untouched. Manual activation and
  `--no-shell-hook` remain available for intentionally unmanaged hooks.
- Preflight rejects known invalid hooks before payload publication. Hook changes
  are not a single multi-file transaction: later write failures or filesystem races
  can leave an installed payload with partial hooks. Review the resulting state
  before retrying.
- On interrupted payload updates or failed restoration, retain the recovery backup
  and report its path. Never delete the only recoverable copy to make cleanup appear complete.
  Environment-diff execution must preserve a failed initialization status.
- `MANTLE_CREATE_XDG_DIRECTORIES=0` skips XDG initialization's base directories,
  not every write during activation. Enabled history and other modules can create
  their own state directories. A real, user-owned private `XDG_RUNTIME_DIR` is an
  intentional security exception:
  validate it, reject a final-component symlink before chmod and ensure mode `0700`.
  The [XDG specification](https://specifications.freedesktop.org/basedir/latest/)
  also requires absolute roots and ordered search directories. Bash and Fish must
  normalize invalid roots and preserve the colon-delimited `XDG_DATA_DIRS` contract.
- An automatically selected Bash/Zsh Codex root must be owned, private and free
  of a final-component symlink. Explicit `CODEX_HOME` is left untouched; a missing
  automatic root is not created when XDG base-directory creation is disabled.
- Fish shares core XDG validation and private-runtime handling, but its tool
  bindings cover a selected language/cache subset. It does not yet mirror the
  full Bash/Zsh tool, AI-state, cache or history policy. Do not infer complete
  tool-binding parity from these core safeguards.

## Preferred Mac alias configuration

Before first activation, place literal settings in
`"$XDG_CONFIG_HOME/mantle/config.conf"` (default
`"$HOME/.config/mantle/config.conf"`):

```ini
schema_version=1
profile=workstation
aliases.legacy=false
aliases.safe=true
```

The exact environment overrides are:

```sh
export MANTLE_ENABLE_LEGACY_ALIASES=0
export MANTLE_ENABLE_SAFE_ALIASES=1
```

Explicit environment values override the file. The focused safe group provides
`l`, `la` and `ll`, using eza when available and native ls otherwise; it does not
replace `ls`. Network/system/safety groups are independently optional and default
off. Disabling one group does not remove helpers from the legacy corpus, so
`aliases.legacy=false` matters. Existing user aliases remain outside this policy.
These groups require an interactive shell and an interactive-capable profile.
Use a fresh terminal outside an activated session to avoid inherited environment
and earlier aliases. This preference does not change compatibility defaults.

## XDG reconciliation before a later Mac refresh

Inventory the installed application/version and both old and proposed locations
before choosing a path. Explicit tool variables win. For guarded bindings, an
existing legacy path (including a broken link) now wins even when an XDG target
also exists; history likewise preserves its existing legacy/prior Mantle file.
This intentionally changes the previous both-roots selection. Set the tool's
explicit variable to opt into a chosen XDG root, then reconcile application state
separately. Startup does not merge, move or delete that data. The
[exception inventory](../config/xdg-exceptions.tsv) records incomplete support.

- `MINIKUBE_HOME` normally names a parent directory: Minikube adds `.minikube`,
  except when the supplied path already ends in `.minikube`. Check the resulting
  data path rather than assuming the variable directly names it.
  [Upstream implementation](https://github.com/kubernetes/minikube/blob/master/pkg/minikube/localpath/localpath.go#L43).
- CPython's `PYTHON_HISTORY` relocation requires Python 3.13 or later. Older
  interpreters need their own reviewed configuration; exporting the variable does
  not prove relocation. This is a history-support boundary, not a new Python
  dependency for shell startup.
  [Versioned Python documentation](https://docs.python.org/3.13/using/cmdline.html#envvar-PYTHON_HISTORY).
- Identify the owner of `~/.net`. For .NET single-file application extraction,
  `DOTNET_BUNDLE_EXTRACT_BASE_DIR` selects a protected extraction base; it is
  separate from `DOTNET_CLI_HOME` and is not a universal assembly-store policy.
  [Microsoft's deployment guide](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview#native-libraries).
- Check current application contracts: Claude Code documents `CLAUDE_CONFIG_DIR`
  and OpenHands CLI documents `OPENHANDS_PERSISTENCE_DIR` and
  `OPENHANDS_CONVERSATIONS_DIR`. Older tools or similarly named products may
  differ. Review credentials and existing state before any later migration.
  [Claude Code](https://code.claude.com/docs/en/claude-directory);
  [OpenHands CLI](https://github.com/OpenHands/OpenHands-CLI/blob/main/openhands_cli/locations.py).
- GUI applications, launch agents and services may not inherit a terminal's
  exports. Configure their own launch environment deliberately and qualify it
  separately; shell activation alone is insufficient. For example,
  [Ollama documents macOS launch environments](https://github.com/ollama/ollama/blob/main/docs/faq.mdx#setting-environment-variables-on-mac).

Finish temporary-HOME qualification and review an application-by-application
migration plan before a later real Mac refresh. Keep backups and an explicit
rollback path; no migration commands are prescribed here.
