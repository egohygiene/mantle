#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide small capability and filesystem predicates shared by Mantle.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/core/guards.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_GUARDS_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Return whether a command is available to the active shell.
# @arg $1 string Command name or path.
# @exitcode 0 The command is available.
# @exitcode 1 The command is unavailable.
# @exitcode 64 Usage is invalid.
mantle_guard_has_command() {
	if (($# != 1)) || [[ -z "${1:-}" ]]; then
		return 64
	fi

	command -v "$1" >/dev/null 2>&1
}

# @description Return whether a path is a regular file.
# @arg $1 string File path.
mantle_guard_file_exists() {
	(($# == 1)) && [[ -n "${1:-}" && -f "$1" ]]
}

# @description Return whether a path is a directory.
# @arg $1 string Directory path.
mantle_guard_directory_exists() {
	(($# == 1)) && [[ -n "${1:-}" && -d "$1" ]]
}

# @description Return whether a path is executable.
# @arg $1 string File or command path.
mantle_file_is_executable() {
	(($# == 1)) && [[ -n "${1:-}" && -x "$1" ]]
}

# @description Return whether a regular file begins with a shebang.
# @arg $1 string File path.
mantle_file_has_shebang() {
	local file_path="${1:-}"
	local file_prefix=""

	if (($# != 1)) || [[ -z "${file_path}" || ! -f "${file_path}" ]]; then
		return 1
	fi

	file_prefix="$(LC_ALL=C head -c 2 "${file_path}" 2>/dev/null)" || return 1
	[[ "${file_prefix}" == "#!" ]]
}

MANTLE_GUARDS_LIBRARY_LOADED="1"

return 0
