#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide quiet-by-default, stderr-only structured logging for Mantle.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/core/logging.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_LOGGING_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_log_print() {
	local log_level="${1:-info}"
	local color_prefix="${2:-}"
	shift 2 || return 64

	printf "%b[mantle:%s]%b %s\n" \
		"${color_prefix}" \
		"${log_level}" \
		"${MANTLE_COLOR_RESET:-}" \
		"$*" >&2
}

# @description Print an informational Mantle message to standard error.
# @arg $@ string Message words.
mantle_log_info() {
	__mantle_log_print "info" "${MANTLE_COLOR_BOLD_BLUE:-}" "$@"
}

# @description Print a warning Mantle message to standard error.
# @arg $@ string Message words.
mantle_log_warn() {
	__mantle_log_print "warn" "${MANTLE_COLOR_BOLD_YELLOW:-}" "$@"
}

# @description Print an error Mantle message to standard error.
# @arg $@ string Message words.
mantle_log_error() {
	__mantle_log_print "error" "${MANTLE_COLOR_BOLD_RED:-}" "$@"
}

# @description Print a success Mantle message to standard error.
# @arg $@ string Message words.
mantle_log_success() {
	__mantle_log_print "ok" "${MANTLE_COLOR_BOLD_GREEN:-}" "$@"
}

# @description Print a debug message when MANTLE_DEBUG is enabled.
# @arg $@ string Message words.
mantle_log_debug() {
	case "${MANTLE_DEBUG:-0}" in
		1 | true | yes | on)
			__mantle_log_print "debug" "${MANTLE_COLOR_DIM:-}" "$@"
			;;
	esac
}

MANTLE_LOGGING_LIBRARY_LOADED="1"

return 0
