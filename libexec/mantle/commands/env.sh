#!/usr/bin/env bash
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Print Mantle-owned runtime state without exposing the entire environment.

set -o errexit
set -o nounset
set -o pipefail

# @description Describe allowlisted environment inspection without shell initialization.
# @stdout Usage and output formats.
mantle_env_usage() {
	printf "%s\n" \
		"Usage: mantle env [--shell] [--help]" \
		"" \
		"Print the public Mantle environment contract." \
		"Use --shell to emit safely quoted Bash-compatible export statements." \
		"Only named Mantle/XDG state is read; arbitrary environment variables are never dumped."
}

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

mantle_env_format="text"
while (($# > 0)); do
	case "$1" in
	--summary)
		printf "Show Mantle's public environment state.\n"
		exit 0
		;;
	--shell)
		mantle_env_format="shell"
		shift
		;;
	--help | -h)
		mantle_env_usage
		exit 0
		;;
	*)
		printf "[mantle:error] unknown env option\n" >&2
		mantle_env_usage >&2
		exit 64
		;;
	esac
done

# @description Print one explicitly allowlisted public variable without evaluating its value.
# @arg $1 string Fixed public variable name.
# @arg $2 string Inherited value.
# @stdout Human-readable escaped state or a Bash-compatible export statement.
mantle_env_print() {
	local variable_name="$1"
	local variable_value="$2"

	if [[ "${mantle_env_format}" == "shell" ]]; then
		printf "export %s=%q\n" "${variable_name}" "${variable_value}"
	else
		if [[ -n "${variable_value}" ]]; then
			printf "%-35s %q\n" "${variable_name}" "${variable_value}"
		else
			printf "%-35s <unset>\n" "${variable_name}"
		fi
	fi
}

mantle_env_print "MANTLE_ROOT" "${MANTLE_ROOT}"
mantle_env_print "MANTLE_INITIALIZATION_STATE" "${MANTLE_INITIALIZATION_STATE:-}"
mantle_env_print "MANTLE_RUNTIME_ENVIRONMENT" "${MANTLE_RUNTIME_ENVIRONMENT:-}"
mantle_env_print "MANTLE_SHELL_NAME" "${MANTLE_SHELL_NAME:-}"
mantle_env_print "MANTLE_INTERACTIVE" "${MANTLE_INTERACTIVE:-}"
mantle_env_print "MANTLE_PROFILE" "${MANTLE_PROFILE:-}"
mantle_env_print "MANTLE_ACTIVE_PROFILE" "${MANTLE_ACTIVE_PROFILE:-}"
mantle_env_print "MANTLE_PROFILE_CAPABILITIES" "${MANTLE_PROFILE_CAPABILITIES:-}"
mantle_env_print "MANTLE_PROFILE_SOURCE" "${MANTLE_PROFILE_SOURCE:-}"
mantle_env_print "MANTLE_POLICY_ALIASES_SAFE" "${MANTLE_POLICY_ALIASES_SAFE:-}"
mantle_env_print "MANTLE_POLICY_ALIASES_NETWORK" "${MANTLE_POLICY_ALIASES_NETWORK:-}"
mantle_env_print "MANTLE_POLICY_ALIASES_SYSTEM" "${MANTLE_POLICY_ALIASES_SYSTEM:-}"
mantle_env_print "MANTLE_POLICY_ALIASES_LEGACY" "${MANTLE_POLICY_ALIASES_LEGACY:-}"
mantle_env_print "MANTLE_POLICY_ALIASES_SAFETY" "${MANTLE_POLICY_ALIASES_SAFETY:-}"
mantle_env_print "MANTLE_POLICY_HISTORY" "${MANTLE_POLICY_HISTORY:-}"
mantle_env_print "MANTLE_POLICY_SUPPRESS_UPDATE_CHECKS" "${MANTLE_POLICY_SUPPRESS_UPDATE_CHECKS:-}"
mantle_env_print "MANTLE_POLICY_EXPERIMENTAL" "${MANTLE_POLICY_EXPERIMENTAL:-}"
mantle_env_print "MANTLE_POLICY_PRESENTATION" "${MANTLE_POLICY_PRESENTATION:-}"
mantle_env_print "MANTLE_CONFIG_SCHEMA_VERSION" "${MANTLE_CONFIG_SCHEMA_VERSION:-}"
mantle_env_print "MANTLE_CONFIG_FILE_RESOLVED" "${MANTLE_CONFIG_FILE_RESOLVED:-}"
mantle_env_print "MANTLE_CONFIG_FILE_STATUS" "${MANTLE_CONFIG_FILE_STATUS:-}"
mantle_env_print "MANTLE_XDG_MIGRATION_WARNINGS" "${MANTLE_XDG_MIGRATION_WARNINGS:-}"
mantle_env_print "XDG_CONFIG_HOME" "${XDG_CONFIG_HOME:-}"
mantle_env_print "XDG_CACHE_HOME" "${XDG_CACHE_HOME:-}"
mantle_env_print "XDG_DATA_HOME" "${XDG_DATA_HOME:-}"
mantle_env_print "XDG_STATE_HOME" "${XDG_STATE_HOME:-}"
mantle_env_print "XDG_RUNTIME_DIR" "${XDG_RUNTIME_DIR:-}"
mantle_env_print "XDG_BIN_HOME" "${XDG_BIN_HOME:-}"
