#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide explicit terminal and shell-profile helpers for Bash.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/terminal.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_TERMINAL_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Return whether standard output is attached to a terminal.
mantle_terminal_is_terminal() {
	[[ -t 1 ]]
}

# @description Print the canonical startup profile for the active shell.
mantle_terminal_profile_path() {
	local shell_name="${MANTLE_SHELL_NAME:-${SHELL##*/}}"

	if (($# != 0)) || [[ -z "${HOME:-}" ]]; then
		return 64
	fi

	case "${shell_name}" in
		bash) printf "%s/.bashrc\n" "${HOME}" ;;
		zsh) printf "%s/.zshrc\n" "${HOME}" ;;
		*) printf "%s/.profile\n" "${HOME}" ;;
	esac
}

# @description Move upward and clear the requested number of terminal lines.
mantle_terminal_clear_lines() {
	local line_count="${1:-1}"
	local line_index=0

	if (($# > 1)) || [[ ! "${line_count}" =~ ^[1-9][0-9]*$ ]]; then
		return 64
	fi
	if ! mantle_terminal_is_terminal; then
		return 0
	fi

	for ((line_index = 0; line_index < line_count; line_index++)); do
		printf "\033[1A\033[2K"
	done
}

# @description Load GNU dircolors output into LS_COLORS when available.
# @arg $1 string Optional dircolors configuration file.
mantle_terminal_load_dircolors() {
	local configuration_path="${1:-}"
	local generated_shell_code=""

	if (($# > 1)); then
		return 64
	fi
	command -v dircolors >/dev/null 2>&1 || return 127

	if [[ -z "${configuration_path}" ]]; then
		configuration_path="${MANTLE_CONFIG_HOME:-${XDG_CONFIG_HOME:-${HOME:-}/.config}}/dircolors"
	fi

	if [[ -r "${configuration_path}" ]]; then
		generated_shell_code="$(dircolors --sh "${configuration_path}")" || return $?
	else
		generated_shell_code="$(dircolors --sh)" || return $?
	fi

	# dircolors is the sole producer of this shell assignment code.
	# shellcheck disable=SC2294
	eval "${generated_shell_code}"
}

MANTLE_TERMINAL_LIBRARY_LOADED="1"

return 0
