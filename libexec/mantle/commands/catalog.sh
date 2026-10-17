#!/usr/bin/env bash
# shellcheck shell=bash
# Read-only command applicability metadata, without installing or running tools.

set -o errexit
set -o nounset
set -o pipefail

# @description Print command catalog usage without optional dependencies.
# @stdout Public usage and catalog semantics.
mantle_catalog_usage() {
	printf "%s\n" \
		"Usage: mantle catalog list [--profile PROFILE] [--json]" \
		"       mantle catalog validate [--json]" \
		"" \
		"List maintained metadata for flat bin commands and public Mantle commands." \
		"Profile filtering includes inherited profiles and is a recommendation, not access control." \
		"Unknown legacy requirements are null in JSON and remain unreviewed." \
		"No dependencies are installed and no cataloged commands are executed." \
		"Catalog inspection requires Python 3.9 or newer; shell startup does not." \
		"Exit codes: 0 complete, 64 usage, 69 missing dependency, 78 invalid metadata."
}

case "${1:-}" in
--summary)
	printf "List and validate public command metadata and profile recommendations.\n"
	exit 0
	;;
esac

for mantle_catalog_argument in "$@"; do
	[[ "${mantle_catalog_argument}" != "--" ]] || break
	if [[ "${mantle_catalog_argument}" == "--help" || "${mantle_catalog_argument}" == "-h" ]]; then
		mantle_catalog_usage
		exit 0
	fi
done

case "${1:-}" in
list | validate) ;;
*)
	mantle_catalog_usage >&2
	exit 64
	;;
esac

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi
if ! command -v python3 >/dev/null 2>&1; then
	printf "[mantle:error] command catalog inspection requires Python 3.9 or newer (python3).\n" >&2
	exit 69
fi
exec python3 "${MANTLE_ROOT}/libexec/mantle/metadata.py" catalog "$@"
