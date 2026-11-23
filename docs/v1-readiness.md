# Proposed Mantle v1 readiness

Snapshot: 2026-11-23. `v1.0.0` is a proposed candidate, not a published release.
The source baseline is `c43897056cc43040a3f7c845e855d433213397b7` with
`VERSION=0.1.0-dev`. This draft consolidates source-reviewed installer, XDG and interpreter fixes.
The execution environment is still starting at this checkpoint; tests, syntax,
static checks, native-platform runs and artifact verification have NOT RUN for
the combined candidate. Prior README-only receipts do not qualify this source.

## Exit criteria

| Gate | Current status | Required evidence before release |
| --- | --- | --- |
| Reviewed source | Prepared from reviewed candidate heads; combined execution untested | Review the final combined commit, including installer recovery, shared XDG safety, limited Fish tool bindings and interpreter selection. |
| Linux | Pending for the combined commit | Strict validation, profile/catalog checks and the temporary-HOME install lifecycle pass with tool versions and optional skips recorded. |
| Native macOS | Pending | Stock Bash 3.2 and native Zsh qualification on a real Mac, including temporary-HOME lifecycle and startup regressions. Record OS and architecture; qualify each architecture claimed. |
| Hosted qualification | Pending | Successful manual Linux, native macOS and static jobs for the exact reviewed main revision, as required by the release workflow. Local runs do not satisfy this gate. |
| Release integrity | Pending; no artifact verified here | Reviewed changelog promotion, pinned packaging, actual signature and build-attestation verification, retained checksums and source evidence. |
| Publication | Pending separate approval | Publish only the reviewed stable tag and verified bundle through the existing release boundary. |

Linux is the first runtime target; native macOS is required before describing the
candidate as ready for a Mac refresh. MSYS2/Git Bash remains experimental;
native PowerShell and universal portability are not promised by these checks.
See [release and recovery](release.md) and the live
[execution tracker](https://github.com/egohygiene/mantle/issues/45).

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
- `MANTLE_CREATE_XDG_DIRECTORIES=0` skips ordinary directory creation. A real,
  user-owned private `XDG_RUNTIME_DIR` is an intentional security exception:
  validate it, reject a final-component symlink before chmod and ensure mode `0700`.
  The [XDG specification](https://specifications.freedesktop.org/basedir/latest/)
  also requires absolute roots and ordered search directories. Bash and Fish must
  normalize invalid roots and preserve the colon-delimited `XDG_DATA_DIRS` contract.
- An automatically selected Bash/Zsh Codex root must be owned, private and free
  of a final-component symlink. Explicit `CODEX_HOME` is left untouched; a missing
  automatic root is not created when ordinary directory creation is disabled.
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
