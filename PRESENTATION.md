# Startup presentation

Mantle stays quiet by default. Set `MANTLE_STARTUP_DISPLAY=1` explicitly to
request a display after successful initialization on an interactive terminal.
Bash, Zsh, and Fish use the shared `mantle startup` command and the existing
`MANTLE_STARTUP_SHOWN` once-per-session guard.

## Presentation modes

The optional configuration setting `presentation` selects the mode. An explicit
`MANTLE_PRESENTATION_MODE` environment value takes precedence; an initialized
shell exports the effective `MANTLE_POLICY_PRESENTATION` for the shared command.

| Mode | Behavior after explicit display opt-in |
| --- | --- |
| `private` | Existing configurable text banner and optional Fastfetch dashboard. |
| `share-safe` | Bundled public text artwork only; never runs Fastfetch or reads custom banner/configuration paths. |
| `ci` | No display. |
| `off` | No display. |

The mode does not bypass the interactive, terminal, CI, or already-shown guards.
It does not enable startup output by itself. In `share-safe`, setting
`MANTLE_STARTUP_BANNER=0` suppresses the remaining text as well.

The private mode can display local machine and workspace information. Custom
Fastfetch profiles are trusted user code; Mantle does not sanitize their output.
The share-safe mode controls only Mantle's startup display, not other shell
configuration, prompts, terminal scrollback, or screen contents.

## Diagnostics and lifetime

Run `mantle startup --check` to check eligibility: zero means an eligible attempt,
one means suppressed. `mantle startup --diagnostics` adds status and elapsed-time
information for an enabled attempt. Display failures remain nonfatal.

The shared deadline runner preserves a foreground terminal for renderers and
terminates its operation group when the configured budget expires. Startup
never installs Fastfetch or performs a Mantle-owned network lookup. Existing
XDG Fastfetch configuration remains preferred in private mode; installed copies
retain their bundled artwork.

See [the startup controls in README](README.md#optional-incompris-startup-dashboard)
for individual switches, timeout limits, logo selection, and redisplay. The
standalone [shell-banner command](bin/shell-banner) remains independently usable.
