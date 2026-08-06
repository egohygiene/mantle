#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide Bash variable and scalar-value predicates.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/variable.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_VARIABLE_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Return whether a named Bash variable is an indexed or associative array.
mantle_variable_is_array() {
	local declaration=""

	if (($# != 1)) || [[ ! "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
		return 1
	fi

	declaration="$(declare -p "$1" 2>/dev/null)" || return 1
	[[ "${declaration}" == "declare -a "* || "${declaration}" == "declare -A "* ]]
}

# @description Return whether a value contains one or more decimal digits.
mantle_variable_is_numeric() {
	(($# == 1)) && [[ "$1" =~ ^[0-9]+$ ]]
}

# @description Return whether a value is a signed decimal integer.
mantle_variable_is_integer() {
	(($# == 1)) && [[ "$1" =~ ^[+-]?[0-9]+$ ]]
}

# @description Return whether a value is a signed integer or decimal number.
mantle_variable_is_float() {
	(($# == 1)) && [[ "$1" =~ ^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]]
}

# @description Return whether a value is a recognized boolean spelling.
mantle_variable_is_boolean() {
	if (($# != 1)); then
		return 1
	fi

	case "$1" in
	0 | 1 | true | false | yes | no | on | off) return 0 ;;
	*) return 1 ;;
	esac
}

# @description Return whether a value represents an enabled state.
mantle_variable_is_true() {
	if (($# != 1)); then
		return 1
	fi

	case "$1" in
	1 | true | yes | on) return 0 ;;
	*) return 1 ;;
	esac
}

# @description Return whether a value represents a disabled state.
mantle_variable_is_false() {
	if (($# != 1)); then
		return 1
	fi

	case "$1" in
	0 | false | no | off) return 0 ;;
	*) return 1 ;;
	esac
}

# @description Return whether a value is empty or the JSON null spelling.
mantle_variable_is_empty_or_null() {
	(($# == 1)) && [[ -z "$1" || "$1" == "null" ]]
}

MANTLE_VARIABLE_LIBRARY_LOADED="1"

return 0
