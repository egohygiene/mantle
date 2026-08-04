#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide opt-in debugging helpers for Bash scripts.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/debug.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_DEBUG_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Print an indexed or associative Bash array as key-value pairs.
# @arg $1 string Array variable name.
# @exitcode 69 The active Bash version does not support namerefs.
mantle_debug_print_array() {
	local array_name="${1:-}"
	local array_declaration=""
	local array_key=""

	if (($# != 1)) || [[ ! "${array_name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
		return 64
	fi

	if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3))); then
		return 69
	fi

	array_declaration="$(declare -p "${array_name}" 2>/dev/null)" || return 1
	if [[ "${array_declaration}" != "declare -a "* &&
		"${array_declaration}" != "declare -A "* ]]; then
		return 1
	fi

	# This branch is reached only on Bash 4.3+, where namerefs are available.
	local -n array_reference="${array_name}"
	for array_key in "${!array_reference[@]}"; do
		printf "%s = %s\n" "${array_key}" "${array_reference[${array_key}]}"
	done
}

# @description Print a string with escape bytes represented as backslash-e.
mantle_debug_print_ansi() {
	if (($# != 1)); then
		return 64
	fi

	printf "%s\n" "${1//$'\e'/\\e}"
}

# @description Run a command quietly unless Mantle debugging is enabled.
mantle_debug_execute() {
	if (($# == 0)); then
		return 64
	fi

	case "${MANTLE_DEBUG:-0}" in
		1 | true | yes | on) "$@" ;;
		*) "$@" >/dev/null 2>&1 ;;
	esac
}

MANTLE_DEBUG_LIBRARY_LOADED="1"

return 0
