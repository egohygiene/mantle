#!/usr/bin/env bash
# shellcheck shell=bash
#
# Detect the active shell runtime and expose shell-specific predicates.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/core/shell.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_SHELL_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -n "${BASH_VERSION:-}" ]]; then
	__mantle_detected_shell_name="bash"
	__mantle_detected_shell_version="${BASH_VERSION}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
	__mantle_detected_shell_name="zsh"
	__mantle_detected_shell_version="${ZSH_VERSION}"
elif [[ -n "${KSH_VERSION:-}" ]]; then
	__mantle_detected_shell_name="ksh"
	__mantle_detected_shell_version="${KSH_VERSION}"
else
	__mantle_detected_shell_name="posix"
	__mantle_detected_shell_version="unknown"
fi

if [[ -n "${MANTLE_SHELL_NAME:-}" &&
	"${MANTLE_SHELL_NAME}" != "${__mantle_detected_shell_name}" &&
	"${MANTLE_DEBUG:-0}" == "1" ]]; then
	printf "[mantle:debug] replacing inherited shell name %s with detected shell %s\n" \
		"${MANTLE_SHELL_NAME}" "${__mantle_detected_shell_name}" >&2
fi

MANTLE_SHELL_NAME="${__mantle_detected_shell_name}"
MANTLE_SHELL_VERSION="${__mantle_detected_shell_version}"

if [[ "$-" == *i* ]]; then
	MANTLE_INTERACTIVE="1"
else
	MANTLE_INTERACTIVE="0"
fi

export MANTLE_SHELL_NAME
export MANTLE_SHELL_VERSION
export MANTLE_INTERACTIVE

# @description Print the active shell runtime name.
# @stdout bash, zsh, ksh, or posix.
mantle_shell_name() {
	printf "%s\n" "${MANTLE_SHELL_NAME:-posix}"
}

# @description Print the active shell runtime version.
# @stdout The shell version or unknown.
mantle_shell_version() {
	printf "%s\n" "${MANTLE_SHELL_VERSION:-unknown}"
}

# @description Return whether the active shell is Bash.
# @exitcode 0 The active shell is Bash.
# @exitcode 1 The active shell is not Bash.
mantle_shell_is_bash() {
	[[ "${MANTLE_SHELL_NAME:-posix}" == "bash" ]]
}

# @description Return whether the active shell is Zsh.
# @exitcode 0 The active shell is Zsh.
# @exitcode 1 The active shell is not Zsh.
mantle_shell_is_zsh() {
	[[ "${MANTLE_SHELL_NAME:-posix}" == "zsh" ]]
}

# @description Return whether the active shell is a generic POSIX-style shell.
# @exitcode 0 The active shell is ksh or the generic POSIX runtime.
# @exitcode 1 The active shell is Bash or Zsh.
mantle_shell_is_posix() {
	case "${MANTLE_SHELL_NAME:-posix}" in
		ksh | posix)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

# @description Return whether the active shell is interactive.
# @exitcode 0 The active shell is interactive.
# @exitcode 1 The active shell is noninteractive.
mantle_shell_is_interactive() {
	[[ "${MANTLE_INTERACTIVE:-0}" == "1" ]]
}

MANTLE_SHELL_LIBRARY_LOADED="1"

unset __mantle_detected_shell_name
unset __mantle_detected_shell_version

return 0
