#!/usr/bin/env bash
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Inspect and validate Mantle's versioned profile configuration.

set -o errexit
set -o nounset
set -o pipefail

# @description Print typed configuration inspection commands without loading runtime policy.
# @stdout Public usage and precedence rules.
mantle_config_usage() {
	printf "%s\n" \
		"Usage: mantle config <command> [arguments]" \
		"" \
		"Commands:" \
		"  list-profiles       List the six profiles, parents, and capabilities." \
		"  path                Print the resolved configuration file path." \
		"  validate [FILE]     Validate a file without executing it." \
		"  show                Print the effective configuration as key=value." \
		"  explain [SETTING]   Explain effective values and their sources." \
		"" \
		"Precedence: profile defaults < config file < environment overrides." \
		"Files are literal key=value data; this command never sources them as shell code."
}

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

if [[ "${1:-}" == "--summary" ]]; then
	printf "Validate literal configuration and explain effective Mantle policy.\n"
	exit 0
fi
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	mantle_config_usage
	exit 0
fi
if (($# == 0)); then
	mantle_config_usage >&2
	exit 64
fi

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/config/profile.sh"

# @description Resolve the selected profile and typed policy without initializing the shell.
# @exitcode 64 An environment profile is invalid.
# @exitcode 66 An explicitly selected file is unavailable.
# @exitcode 78 Configuration content is invalid.
mantle_config_cli_resolve() {
	mantle_config_resolve || exit $?
}

# @description Validate and list repository-owned profile graph rows without Python.
# @stdout The profile/parents/capabilities TSV table.
mantle_config_cli_list_profiles() {
	local profile=""
	local parents=""
	local capabilities=""
	local graph_result=""
	if ! command -v awk >/dev/null 2>&1; then
		printf "[mantle:error] profile graph inspection requires awk\n" >&2
		return 69
	fi
	if ! graph_result="$(command awk -v selected=full -f "${MANTLE_ROOT}/lib/core/profiles.awk" \
		"${MANTLE_ROOT}/config/profiles.tsv")"; then
		printf "%s\n" "${graph_result}" >&2
		return 64
	fi
	printf "profile\tparents\tcapabilities\n"
	while IFS=$'\t' read -r profile parents capabilities; do
		[[ "${profile}" == "profile" ]] && continue
		printf "%s\t%s\t%s\n" "${profile}" "${parents}" "${capabilities}"
	done <"${MANTLE_ROOT}/config/profiles.tsv"
}

# @description Print the resolved schema, profile, and typed setting values.
# @stdout Stable key=value records.
mantle_config_cli_show() {
	local setting_name=""
	local _setting_metadata=""
	local setting_variable=""
	local effective_value=""

	printf "schema_version=%s\n" "${MANTLE_CONFIG_SCHEMA_VERSION}"
	printf "profile=%s\n" "${MANTLE_PROFILE}"
	while IFS=$'\t' read -r setting_name _setting_metadata; do
		[[ "${setting_name}" == "setting" ]] && continue
		setting_variable="$(mantle_config_setting_variable "${setting_name}")" || exit 78
		effective_value="$(mantle_config_get_policy_value "${setting_variable}")" || exit 78
		printf "%s=%s\n" "${setting_name}" "${effective_value}"
	done <"${MANTLE_ROOT}/config/settings.tsv"
}

mantle_config_subcommand="$1"
shift
case "${mantle_config_subcommand}" in
list-profiles)
	(($# == 0)) || {
		printf "[mantle:error] config list-profiles does not accept arguments\n" >&2
		exit 64
	}
	mantle_config_cli_list_profiles
	;;
path)
	(($# == 0)) || {
		printf "[mantle:error] config path does not accept arguments\n" >&2
		exit 64
	}
	mantle_config_cli_resolve
	printf "%s\n" "${MANTLE_CONFIG_FILE_RESOLVED}"
	;;
validate)
	if (($# > 1)); then
		printf "[mantle:error] config validate accepts at most one file\n" >&2
		exit 64
	fi
	if (($# == 1)); then
		if [[ ! -f "$1" || ! -r "$1" ]]; then
			printf "[mantle:error] configured Mantle config file is unavailable\n" >&2
			exit 66
		fi
		if [[ "$1" == /* ]]; then
			MANTLE_CONFIG_FILE="$1"
		else
			MANTLE_CONFIG_FILE="$(cd -P "$(dirname -- "$1")" && pwd)/$(basename -- "$1")"
		fi
		export MANTLE_CONFIG_FILE
	fi
	mantle_config_cli_resolve
	printf "status: %s\n" "${MANTLE_CONFIG_FILE_STATUS}"
	printf "schema_version: %s\n" "${MANTLE_CONFIG_SCHEMA_VERSION}"
	printf "profile: %s\n" "${MANTLE_PROFILE}"
	;;
show)
	(($# == 0)) || {
		printf "[mantle:error] config show does not accept arguments\n" >&2
		exit 64
	}
	mantle_config_cli_resolve
	mantle_config_cli_show
	;;
explain)
	if (($# > 1)); then
		printf "[mantle:error] config explain accepts at most one setting\n" >&2
		exit 64
	fi
	if (($# == 1)) && [[ "$1" != "profile" ]] && ! mantle_config_setting_variable "$1" >/dev/null; then
		printf "[mantle:error] unknown config setting\n" >&2
		exit 64
	fi
	mantle_config_cli_resolve
	mantle_config_print_effective "${1:-}"
	;;
--help | -h)
	mantle_config_usage
	;;
*)
	printf "[mantle:error] unknown config command\n" >&2
	mantle_config_usage >&2
	exit 64
	;;
esac
