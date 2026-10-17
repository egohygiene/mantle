#!/usr/bin/env bash
# shellcheck shell=bash
# Read-only, on-demand local storage diagnostics.

set -o errexit
set -o nounset
set -o pipefail

# @description Print the public storage command interface without optional dependencies.
# @stdout Usage and safety boundaries for storage diagnostics.
mantle_storage_usage() {
	printf "%s\n" \
		"Usage: mantle storage {disk|directory|repo|objects|large-files} [PATH] [--json]" \
		"       mantle storage large-files [PATH] [--limit N] [--min-size BYTES] [--json]" \
		"" \
		"Inspect local storage without modifying files or contacting remotes." \
		"PATH defaults to the current directory. Python 3.9 or newer is required." \
		"Directory scans stay on one filesystem and do not follow symbolic links." \
		"Nested repositories are boundaries; repo/objects require the repository root." \
		"File totals count each hardlinked inode once; allocated bytes measure file blocks." \
		"large-files defaults: --limit 20 --min-size 1048576 (apparent bytes)." \
		"Exit codes: 0 complete, 1 partial/error, 64 usage, 69 missing dependency."
}

case "${1:-}" in
--summary)
	printf "Inspect local disk, directory, repository, and large-file storage.\n"
	exit 0
	;;
esac

for mantle_storage_argument in "$@"; do
	[[ "${mantle_storage_argument}" != "--" ]] || break
	if [[ "${mantle_storage_argument}" == "--help" || "${mantle_storage_argument}" == "-h" ]]; then
		mantle_storage_usage
		exit 0
	fi
done

case "${1:-}" in
disk | directory | repo | objects | large-files) ;;
*)
	mantle_storage_usage >&2
	exit 64
	;;
esac

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

if ! command -v python3 >/dev/null 2>&1; then
	printf "[mantle:error] storage diagnostics require Python 3.9 or newer (python3).\n" >&2
	exit 69
fi

exec python3 "${MANTLE_ROOT}/libexec/mantle/storage.py" "$@"
