#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide side-effect-free Bash string helpers.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/string.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_STRING_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Remove leading and trailing shell whitespace.
mantle_string_trim() {
	local value="${1:-}"

	if (($# != 1)); then
		return 64
	fi

	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf "%s\n" "${value}"
}

# @description Split a string on a literal, nonempty delimiter.
mantle_string_split() {
	local value="${1:-}"
	local delimiter="${2:-}"

	if (($# != 2)) || [[ -z "${delimiter}" ]]; then
		return 64
	fi

	while [[ "${value}" == *"${delimiter}"* ]]; do
		printf "%s\n" "${value%%"${delimiter}"*}"
		value="${value#*"${delimiter}"}"
	done
	printf "%s\n" "${value}"
}

# @description Remove one literal prefix when present.
mantle_string_strip_prefix() {
	if (($# != 2)); then
		return 64
	fi

	if [[ "$1" == "$2"* ]]; then
		printf "%s\n" "${1#"$2"}"
	else
		printf "%s\n" "$1"
	fi
}

# @description Remove one literal suffix when present.
mantle_string_strip_suffix() {
	if (($# != 2)); then
		return 64
	fi

	if [[ "$1" == *"$2" ]]; then
		printf "%s\n" "${1%"$2"}"
	else
		printf "%s\n" "$1"
	fi
}

# @description Convert text to lowercase using the C locale.
mantle_string_to_lower() {
	if (($# != 1)); then
		return 64
	fi
	printf "%s" "$1" | LC_ALL=C tr "[:upper:]" "[:lower:]"
	printf "\n"
}

# @description Convert text to uppercase using the C locale.
mantle_string_to_upper() {
	if (($# != 1)); then
		return 64
	fi
	printf "%s" "$1" | LC_ALL=C tr "[:lower:]" "[:upper:]"
	printf "\n"
}

# @description Return whether text contains a literal substring.
mantle_string_contains() {
	(($# == 2)) && [[ "$1" == *"$2"* ]]
}

# @description Return whether text begins with a literal prefix.
mantle_string_starts_with() {
	(($# == 2)) && [[ "$1" == "$2"* ]]
}

# @description Return whether text ends with a literal suffix.
mantle_string_ends_with() {
	(($# == 2)) && [[ "$1" == *"$2" ]]
}

# @description Return whether text matches a Bash extended regular expression.
mantle_string_matches_regex() {
	(($# == 2)) && [[ "$1" =~ $2 ]]
}

MANTLE_STRING_LIBRARY_LOADED="1"

return 0
