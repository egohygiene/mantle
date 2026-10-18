# Contributing to Mantle

Mantle owns portable shell behavior, command-line utilities, and user-owned
installation primitives. Read [the architecture](ARCHITECTURE.md) before moving
behavior between layers and [the provenance record](PROVENANCE.md) before
importing source or assets.

## Choose the right surface

| Change | Location | Execution contract |
| --- | --- | --- |
| Bash/Zsh activation | `.shellrc`, `init/` | Source into the caller; preserve shell options, working directory, and failure status. |
| Reusable shell primitives | `lib/core/`, `lib/bash/` | Source-only library; retain its interpreter and source guards. |
| Typed configuration | `lib/config/`, `config/settings.tsv` | Parse literal data with fixed keys/types; preserve profile and explicit-environment precedence. |
| Module lifecycle | `lib/modules.sh` | Keep loading transactional, idempotent, and retryable after failure. |
| Portable environment policy | `modules/` | Select defaults and path candidates without installing tools. |
| OS-specific behavior | `platforms/` | Apply after portable modules; keep startup quiet and unprivileged. |
| Native shell adaptation | `runtime/shells/` | Preserve the native shell language; Fish does not source Bash files. |
| Optional shell library | `lib/extensions/` | Load explicitly; network or mutation belongs in functions the user invokes. |
| Public command | `libexec/mantle/commands/<name>.sh` | Executable Bash wrapper dispatched by `bin/mantle`. |
| On-demand Python backend | `libexec/mantle/` | Invoke only from its command wrapper; never from shell initialization. |
| Installer | `libexec/mantle/installers/`, `lib/install/` | Execute through `mantle install`; use the shared install primitives. |
| Existing standalone utility | `bin/` | Preserve its documented language, arguments, and exit statuses. |
| Behavioral evidence | `tests/` | Use the narrowest existing unit, integration, contract, or CLI layer. |

The public dispatcher remains small. Put command-specific parsing and behavior
in the command implementation. Each public command wrapper accepts `--help`
and the internal `--summary` request, consumes the dispatcher's `MANTLE_ROOT`,
and preserves the backend's meaningful status. Help and command discovery must
work without optional media, Python, network, or installation dependencies.

Register maintained paths and permitted source-time dependencies in
[`config/architecture/layers.tsv`](config/architecture/layers.tsv). Its contract
tests enforce one layer owner per path and reject invalid dependency edges.

## Compatibility and startup

Bash implementations target Bash 3.2, including macOS's stock shell. Use indexed
arrays and existing portable helpers instead of newer Bash-only features.
Keep Zsh-native syntax in its adapter and native Fish behavior in Fish files.
Declare platform limits rather than inferring Windows support from Unix tests.

Runtime profiles select initialization capabilities. They do not hide commands,
install dependencies, or replace application authorization. Preserve the
`workstation` compatibility default and the minimal `core`, `container`, and
`ci` behavior documented in [the profile contract](docs/profiles.md).

Do not introduce implicit network requests, package installation, privilege
prompts, or changes to a user's shell preferences during startup. Keep optional
presentation bounded and nonfatal. Tests must use temporary HOME/XDG locations,
controlled command stubs, and loopback services where needed; never mutate real
dotfiles, credentials, remotes, or installed packages.

## Style and provenance

- Use descriptive names, explicit validation, double-quoted shell expansions,
  and long command-line options where the tool supports them.
- Prefer `printf` to `echo`. Document new shell functions with shdoc
  `@description`, argument, output, and meaningful exit-code annotations.
- Follow `.editorconfig` and the maintained source inventory in `tests/run.sh`.
  Bash, POSIX, Bats, Zsh, and Fish have separate parsing requirements.
- Keep ShellCheck suppressions local to the relevant operation and explain why
  the warning does not apply.
- Preserve executable modes for public/private executables and non-executable
  modes for source-only runtime libraries. Do not change a source file's role
  by adding a shebang or executable bit alone.
- Preserve existing copyright and license notices. New first-party source
  should carry `Copyright 2026 Ego Hygiene` and `SPDX-License-Identifier: MIT`
  in its language's comment syntax.
- Record the upstream URL, exact revision, license, required notices, and local
  adaptations for copied or adapted material. A compatible license without a
  source record is insufficient provenance.

Generated Identity output is derived from `.identity/` and the pinned compiler;
follow [the Identity guide](docs/identity.md). Repair canonical inputs and
regenerate rather than manually editing generated ownership or brand metadata.

## Add or change a command

1. Define the user-visible arguments, failure behavior, optional dependencies,
   platform limits, and mutation boundary in the issue or specification.
2. Implement the smallest adapter or backend in its existing owner layer.
3. Add or update the entry in `config/commands.json`. Keep unknown legacy
   requirements explicitly unknown; profile applicability is a recommendation.
4. Register each new flat `bin/` executable in `tests/bin/coverage-map.tsv`.
   Extend the existing command tests instead of adding a parallel test runner.
5. Verify help without optional dependencies, useful failures, intended output,
   and any publication, cleanup, credential, or interrupt boundary.
6. Update the relevant user guide and provenance when behavior or source lineage
   changes. Check compatibility before replacing a legacy utility with an alias.

## Validate the change

Run focused checks while iterating, then the complete runner:

```sh
./bin/mantle profiles validate
./bin/mantle catalog validate
./tests/run.sh tests/integration/entrypoint.bats
./tests/run.sh static
./tests/run.sh
```

Before declaring the full validation contract ready, install the declared
tools and run `./tests/run.sh --strict` or `task ci`. `task check` provides the
developer-friendly suite plus the isolated install-lifecycle smoke test.

Use `./tests/run.sh format` when maintained shell sources need formatting.
The optional Task interface delegates to the same commands through
`task validate`, `task test`, and `task doctor`. See [the test guide](tests/README.md)
for tools, stubs, media fixtures, and platform jobs. A skipped optional check is
not evidence that the corresponding shell, platform, or tool works.

Keep commits focused and use Conventional Commits. Describe the resulting
behavior, why it changes, and the validation evidence in the pull request.
Separate introduced failures from independently reproduced baseline failures.
Preserve recovery evidence before removing a historical migration source.
