#!/usr/bin/env bash
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# shellcheck disable=SC2249 # Closed case statements intentionally treat unmatched values as no-ops.
# Report Mantle installation and executable search paths.

set -o errexit
set -o nounset
set -o pipefail

# @description Describe read-only installation and executable-path inspection.
# @stdout Usage and output modes.
mantle_path_usage() {
	printf "%s\n" \
		"Usage: mantle path [--root|--bin|--entries] [--help]" \
		"" \
		"Print Mantle's installation paths or the current PATH one entry per line."
}

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

mantle_path_mode="summary"
if (($# > 1)); then
	printf "[mantle:error] path accepts at most one option\n" >&2
	mantle_path_usage >&2
	exit 64
fi

if (($# == 1)); then
	case "$1" in
	--summary)
		printf "Show Mantle and executable search paths.\n"
		exit 0
		;;
	--root) mantle_path_mode="root" ;;
	--bin) mantle_path_mode="bin" ;;
	--entries) mantle_path_mode="entries" ;;
	--help | -h)
		mantle_path_usage
		exit 0
		;;
	*)
		printf "[mantle:error] unknown path option\n" >&2
		mantle_path_usage >&2
		exit 64
		;;
	esac
fi

case "${mantle_path_mode}" in
root)
	printf "%s\n" "${MANTLE_ROOT}"
	;;
bin)
	printf "%s/bin\n" "${MANTLE_ROOT}"
	;;
entries)
	mantle_path_remaining="${PATH:-}"
	while [[ "${mantle_path_remaining}" == *:* ]]; do
		printf "%s\n" "${mantle_path_remaining%%:*}"
		mantle_path_remaining="${mantle_path_remaining#*:}"
	done
	printf "%s\n" "${mantle_path_remaining}"
	;;
summary)
	printf "root: %s\n" "${MANTLE_ROOT}"
	printf "bin:  %s/bin\n" "${MANTLE_ROOT}"
	;;
esac
