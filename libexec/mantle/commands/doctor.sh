#!/usr/bin/env bash
# shellcheck shell=bash
# Run Mantle's installation-aware shell diagnostics.

set -o errexit
set -o nounset
set -o pipefail

mantle_doctor_usage() {
	printf "%s\n" \
		"Usage: mantle doctor [--deep] [--strict] [--quiet] [--help]" \
		"" \
		"Validate the installed Mantle runtime without changing shell configuration." \
		"Additional options are passed to shell-doctor."
}

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

if (($# > 0)) && [[ "$1" == "--summary" ]]; then
	printf "Check the installed Mantle runtime and shell bootstrap.\n"
	exit 0
fi

if (($# > 0)) && [[ "$1" == "--help" || "$1" == "-h" ]]; then
	mantle_doctor_usage
	exit 0
fi

mantle_doctor_path="${MANTLE_ROOT}/bin/shell-doctor"
if [[ ! -x "${mantle_doctor_path}" ]]; then
	printf "[mantle:error] shell doctor is not executable: %s\n" "${mantle_doctor_path}" >&2
	exit 70
fi

exec "${mantle_doctor_path}" --root "${MANTLE_ROOT}" "$@"
