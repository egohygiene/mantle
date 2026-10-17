#!/usr/bin/env bash
# shellcheck shell=bash
# On-demand profile metadata inspection; never sourced by the shell runtime.

set -o errexit
set -o nounset
set -o pipefail

# @description Print profile introspection usage without optional dependencies.
# @stdout Public usage and metadata boundaries.
mantle_profiles_usage() {
	printf "%s\n" \
		"Usage: mantle profiles list [--json]" \
		"       mantle profiles show PROFILE [--json]" \
		"       mantle profiles validate [--json]" \
		"" \
		"Inspect core, interactive, workstation, container, ci, and full profiles." \
		"Show includes inherited profiles and capabilities. No shell settings are changed." \
		"Introspection requires Python 3.9 or newer; shell startup does not." \
		"Exit codes: 0 complete, 64 usage, 69 missing dependency, 78 invalid metadata."
}

case "${1:-}" in
--summary)
	printf "Inspect and validate runtime profiles and inherited capabilities.\n"
	exit 0
	;;
esac

for mantle_profiles_argument in "$@"; do
	[[ "${mantle_profiles_argument}" != "--" ]] || break
	if [[ "${mantle_profiles_argument}" == "--help" || "${mantle_profiles_argument}" == "-h" ]]; then
		mantle_profiles_usage
		exit 0
	fi
done

case "${1:-}" in
list | show | validate) ;;
*)
	mantle_profiles_usage >&2
	exit 64
	;;
esac

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi
if ! command -v python3 >/dev/null 2>&1; then
	printf "[mantle:error] profile introspection requires Python 3.9 or newer (python3).\n" >&2
	exit 69
fi
exec python3 "${MANTLE_ROOT}/libexec/mantle/metadata.py" profiles "$@"
