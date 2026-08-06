#!/usr/bin/env bash
# shellcheck shell=bash
# Render top-level and command-specific Mantle help.

set -o errexit
set -o nounset
set -o pipefail

# @description Print top-level Mantle usage and dynamically discovered commands.
mantle_help_usage() {
	local commands_directory="${MANTLE_ROOT}/libexec/mantle/commands"
	local command_path=""
	local command_filename=""
	local command_name=""
	local command_summary=""

	printf "%s\n" \
		"Usage:" \
		"  mantle <command> [arguments]" \
		"  mantle help [command]" \
		"  mantle --help" \
		"  mantle --version" \
		"" \
		"Commands:"

	for command_path in "${commands_directory}"/*.sh; do
		[[ -f "${command_path}" && -x "${command_path}" ]] || continue
		command_filename="${command_path##*/}"
		command_name="${command_filename%.sh}"
		command_summary="$(${command_path} --summary 2>/dev/null)" || command_summary="No description available."
		printf "  %-16s %s\n" "${command_name}" "${command_summary}"
	done

	printf "%s\n" \
		"" \
		"Run 'mantle help <command>' for command-specific usage."
}

# @description Print help-command usage.
mantle_help_command_usage() {
	printf "%s\n" \
		"Usage: mantle help [COMMAND]" \
		"" \
		"Show top-level help or the help page for one command."
}

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

if (($# == 0)); then
	mantle_help_usage
	exit 0
fi

case "$1" in
--summary)
	printf "Show help for Mantle or one command.\n"
	exit 0
	;;
--help | -h)
	mantle_help_command_usage
	exit 0
	;;
-*)
	printf "[mantle:error] unknown help option: %s\n" "$1" >&2
	mantle_help_command_usage >&2
	exit 64
	;;
esac

if (($# != 1)) || [[ ! "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
	printf "[mantle:error] help accepts exactly one command name\n" >&2
	mantle_help_command_usage >&2
	exit 64
fi

mantle_help_command_path="${MANTLE_ROOT}/libexec/mantle/commands/$1.sh"
if [[ ! -f "${mantle_help_command_path}" ]]; then
	printf "[mantle:error] unknown command: %s\n" "$1" >&2
	exit 64
fi
if [[ ! -x "${mantle_help_command_path}" ]]; then
	printf "[mantle:error] command implementation is not executable: %s\n" "${mantle_help_command_path}" >&2
	exit 70
fi

exec "${mantle_help_command_path}" --help
