#!/usr/bin/env bash
# shellcheck shell=bash
# Shared, optional startup policy for Bash, Zsh, and Fish.

set -o nounset
set -o pipefail

mantle_startup_usage() {
	cat <<'EOF'
Usage: mantle startup [--diagnostics] [--check] [--help]

Render the optional local banner and Fastfetch dashboard on an interactive TTY.
Display failures are nonfatal. No installation or network request is performed
by Mantle; custom Fastfetch configurations are trusted user code.

  --diagnostics  Report elapsed seconds, budget, and component exit statuses.
  --check        Check eligibility without rendering; exit 1 when suppressed.

Environment:
  MANTLE_STARTUP_DISPLAY          1 enables the display; default 0 (quiet).
  MANTLE_STARTUP_BANNER           0 disables the text banner; default 1.
  MANTLE_STARTUP_FASTFETCH        0 disables Fastfetch; default 1.
  MANTLE_STARTUP_TIMEOUT_SECONDS  Total display budget, 1..30; default 3.
  MANTLE_STARTUP_DIAGNOSTICS      1 enables status-only diagnostics.
  MANTLE_PRESENTATION_MODE        private/share-safe/ci/off; default private.
  MANTLE_BANNER_FILE              Optional trusted text/ANSI banner file.
  MANTLE_FASTFETCH_CONFIG         Optional existing Fastfetch configuration.
  MANTLE_FASTFETCH_LOGO           Optional readable logo file.
  MANTLE_FASTFETCH_LOGO_TYPE      auto/file/file-raw/chafa/iterm/kitty/kitty-direct/sixel.

Existing XDG Fastfetch configuration takes precedence over Mantle's bundled
profile. A custom profile's logo is preserved unless a logo override is supplied.
Shell adapters export MANTLE_STARTUP_SHOWN after an eligible attempt, suppressing
repeated and nested startup. Unset it to explicitly redisplay in that session.
EOF
}

mantle_startup_eligible() {
	case "${mantle_startup_mode}" in
	private | share-safe) ;;
	*) return 1 ;;
	esac
	[[ "${MANTLE_STARTUP_DISPLAY:-0}" == 1 && "${MANTLE_INTERACTIVE:-0}" == 1 &&
		"${MANTLE_STARTUP_SHOWN:-0}" != 1 && -t 0 && -t 1 &&
		-n "${TERM:-}" && "${TERM}" != dumb &&
		-z "${CI:-}" && -z "${GITHUB_ACTIONS:-}" ]]
}

mantle_startup_diagnostic() {
	[[ "${mantle_startup_diagnostics}" == 1 ]] || return 0
	printf '[mantle:startup] %s\n' "$1" >&2
}

# Passed as a function to the shared deadline runner below.
# shellcheck disable=SC2317
mantle_startup_fastfetch() {
	local config="${MANTLE_FASTFETCH_CONFIG:-}" logo="${MANTLE_FASTFETCH_LOGO:-}"
	local logo_type="${MANTLE_FASTFETCH_LOGO_TYPE:-auto}" bundled=0 status=0
	local config_root="${XDG_CONFIG_HOME:-${HOME:-}/.config}"
	local -a arguments=()
	command -v fastfetch >/dev/null 2>&1 || {
		mantle_startup_diagnostic "fastfetch=unavailable"
		return 0
	}
	if [[ -z "${config}" ]]; then
		if [[ -r "${config_root}/fastfetch/config.jsonc" ]]; then
			config="${config_root}/fastfetch/config.jsonc"
		elif [[ -r "${config_root}/fastfetch/config.json" ]]; then
			config="${config_root}/fastfetch/config.json"
		else
			config="${MANTLE_ROOT}/config/fastfetch/fastfetch.jsonc"
			bundled=1
		fi
	fi
	[[ -f "${config}" && -r "${config}" ]] || {
		mantle_startup_diagnostic "fastfetch=unreadable-config"
		return 0
	}
	[[ "${config}" != "${MANTLE_ROOT}/config/fastfetch/fastfetch.jsonc" ]] || bundled=1
	arguments=(--config "${config}")
	if [[ -z "${logo}" && "${bundled}" == 1 ]]; then
		case "${MANTLE_FASTFETCH_LOGO_TYPE:-}" in
		chafa | iterm | kitty | kitty-direct | sixel)
			logo="${MANTLE_ROOT}/assets/presentation/incompris.png"
			;;
		*)
			case "${TERM_PROGRAM:-}:${TERM:-}:${KITTY_WINDOW_ID:-}" in
			iTerm.app:*)
				logo="${MANTLE_ROOT}/assets/presentation/incompris.png"
				logo_type=iterm
				;;
			*:xterm-kitty:* | *:*:?*)
				logo="${MANTLE_ROOT}/assets/presentation/incompris.png"
				logo_type=kitty-direct
				;;
			*)
				logo="${MANTLE_ROOT}/assets/presentation/incompris.txt"
				logo_type="file"
				;;
			esac
			;;
		esac
	fi
	if [[ -n "${logo}" ]]; then
		[[ -f "${logo}" && -r "${logo}" ]] || {
			mantle_startup_diagnostic "fastfetch=unreadable-logo"
			return 0
		}
		case "${logo_type}" in
		auto | file | file-raw | chafa | iterm | kitty | kitty-direct | sixel) ;;
		*)
			mantle_startup_diagnostic "fastfetch=invalid-logo-type"
			return 0
			;;
		esac
		# Fastfetch expands logo paths with wordexp. Expand a quoted environment
		# variable there instead of interpreting metacharacters in the path itself.
		export MANTLE_STARTUP_LOGO_PATH="${logo}"
		# shellcheck disable=SC2016
		arguments+=(--logo '"$MANTLE_STARTUP_LOGO_PATH"' --logo-type "${logo_type}" --logo-width 32)
	fi
	# The command modules resolve this installation even when startup precedes
	# the caller's PATH setup. No eval or user-shell interpolation is involved.
	PATH="${MANTLE_ROOT}/bin:${PATH}" fastfetch "${arguments[@]}" 2>/dev/null || status=$?
	mantle_startup_diagnostic "fastfetch_status=${status}"
}

# Invoked indirectly by mantle_presentation_run_bounded.
# shellcheck disable=SC2317
mantle_startup_render() {
	local banner="${MANTLE_BANNER_FILE:-${MANTLE_ROOT}/assets/presentation/incompris.txt}" status=0
	if [[ "${mantle_startup_mode}" == share-safe ]]; then
		banner="${MANTLE_ROOT}/assets/presentation/incompris.txt"
	fi
	if [[ "${MANTLE_STARTUP_BANNER:-1}" == 1 ]]; then
		"${MANTLE_ROOT}/bin/shell-banner" --file "${banner}" --logo-only 2>/dev/null || status=$?
		mantle_startup_diagnostic "banner_status=${status}"
	fi
	if [[ "${mantle_startup_fastfetch_enabled}" == 1 ]]; then
		mantle_startup_fastfetch
	fi
	return 0
}

mantle_startup_diagnostics="${MANTLE_STARTUP_DIAGNOSTICS:-0}"
mantle_startup_check=0
for mantle_startup_argument in "$@"; do
	case "${mantle_startup_argument}" in
	--summary)
		printf 'Render the opt-in, bounded interactive startup display.\n'
		exit 0
		;;
	--help | -h)
		mantle_startup_usage
		exit 0
		;;
	--diagnostics) mantle_startup_diagnostics=1 ;;
	--check) mantle_startup_check=1 ;;
	*)
		printf '[mantle:error] unknown startup option\n' >&2
		exit 64
		;;
	esac
done
mantle_startup_mode="${MANTLE_PRESENTATION_MODE:-${MANTLE_POLICY_PRESENTATION:-private}}"
mantle_startup_fastfetch_enabled="${MANTLE_STARTUP_FASTFETCH:-1}"
if [[ "${mantle_startup_mode}" == share-safe ]]; then
	mantle_startup_fastfetch_enabled=0
fi
if ! mantle_startup_eligible; then
	[[ "${mantle_startup_check}" == 0 ]] && exit 0
	exit 1
fi
[[ "${mantle_startup_check}" == 0 ]] || exit 0
# A fully disabled display needs no child job or foreground-terminal handoff.
if [[ "${MANTLE_STARTUP_BANNER:-1}" != 1 && "${mantle_startup_fastfetch_enabled}" != 1 ]]; then
	exit 0
fi
mantle_startup_budget="${MANTLE_STARTUP_TIMEOUT_SECONDS:-3}"
case "${mantle_startup_budget}" in
[1-9] | [12][0-9] | 30) ;;
*)
	mantle_startup_diagnostic "invalid-budget; using 3 seconds"
	mantle_startup_budget=3
	;;
esac
# shellcheck source=lib/presentation/bounded.sh
source "${MANTLE_ROOT}/lib/presentation/bounded.sh"
mantle_startup_started=${SECONDS}
mantle_startup_status=0
mantle_presentation_run_bounded "${mantle_startup_budget}" mantle_startup_render || mantle_startup_status=$?
if ((mantle_startup_status != 0)); then
	# Restore normal terminal presentation after an interrupted optional renderer.
	printf '\033[0m\033[?25h\033[?7h'
fi
mantle_startup_diagnostic "status=${mantle_startup_status} elapsed_seconds=$((SECONDS - mantle_startup_started)) budget_seconds=${mantle_startup_budget}"
exit 0
