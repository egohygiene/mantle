#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide Bash runtime introspection for Mantle's Bash adapter.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/core/bash.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_BASH_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${BASH_VERSION:-}" ]]; then
	printf "[mantle:error] lib/core/bash.sh requires Bash\n" >&2
	return 64
fi

# @description Print the active Bash version.
mantle_bash_version() {
	printf "%s\n" "${BASH_VERSION}"
}

# @description Print the active Bash major version.
mantle_bash_major_version() {
	printf "%s\n" "${BASH_VERSINFO[0]}"
}

# @description Print the active Bash minor version.
mantle_bash_minor_version() {
	printf "%s\n" "${BASH_VERSINFO[1]}"
}

# @description Return whether the current Bash process is interactive.
mantle_bash_is_interactive() {
	[[ "$-" == *i* ]]
}

# @description Print the path of the active Bash executable.
mantle_bash_path() {
	if [[ -n "${BASH:-}" ]]; then
		printf "%s\n" "${BASH}"
	else
		command -v bash 2>/dev/null
	fi
}

# @description Return whether Bash satisfies a minimum major/minor version.
# @arg $1 integer Required major version.
# @arg $2 integer Required minor version.
# @exitcode 0 The version requirement is satisfied.
# @exitcode 1 The version is too old.
# @exitcode 64 Usage is invalid.
mantle_bash_is_minimum_version() {
	local required_major="${1:-}"
	local required_minor="${2:-}"

	if (($# != 2)) || [[ ! "${required_major}" =~ ^[0-9]+$ ||
		! "${required_minor}" =~ ^[0-9]+$ ]]; then
		return 64
	fi

	((BASH_VERSINFO[0] > required_major)) ||
		((BASH_VERSINFO[0] == required_major && BASH_VERSINFO[1] >= required_minor))
}

MANTLE_BASH_LIBRARY_LOADED="1"

return 0
