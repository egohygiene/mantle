# Mantle private commands

`libexec/mantle/` contains executable implementations that are dispatched by
the public `bin/mantle` command. These files are implementation details and do
not belong on `PATH`.

## Layout

```text
libexec/mantle/
├── commands/     # Implement `mantle <command>`.
└── installers/   # Implement `mantle install <tool>`.
```

## Command contract

Each `commands/<name>.sh` file must:

- use Bash and be executable;
- accept `--help` and the internal `--summary` request;
- consume `MANTLE_ROOT` rather than rediscovering the repository;
- preserve meaningful exit statuses from delegated operations; and
- keep command-specific logic out of `bin/mantle`.

The launcher exports `MANTLE_COMMAND_NAME` and `MANTLE_COMMAND_PATH` before
dispatch. The install command additionally exports `MANTLE_INSTALLER_NAME`.

## Installer contract

Installer files are named `installers/<tool>.sh`. They may be executed directly
for debugging, but `mantle install <tool>` is the supported user interface.
Installers source `lib/install/runtime.sh` and use the shared
`MANTLE_INSTALL_*` metadata and `mantle_install_*` APIs.
