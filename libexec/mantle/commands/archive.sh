#!/usr/bin/env bash
# shellcheck shell=bash
# Explicit, read-only project selection and safe local archive publication.

set -o errexit
set -o nounset
set -o pipefail

# @description Describe project archive selection and explicit output requirements.
# @stdout Public archive usage without requiring Python or Git.
mantle_archive_usage() {
	printf "%s\n" \
		"Usage: mantle archive [PATH] --dry-run [--output FILE.tar.gz] [--json]" \
		"       mantle archive [PATH] --output FILE.tar.gz [--reproducible] [--json]" \
		"       Add --include RELATIVE_FILE to explicitly retain an otherwise filtered file." \
		"" \
		"PATH defaults to the current directory. Python 3.9 or newer is required." \
		"Preview selection with --dry-run, which creates no files or directories." \
		"Archives contain regular files under project/; existing outputs are never replaced." \
		"Symlinks, Git metadata, nested repositories, and other filesystems are boundaries." \
		"Common credential, dependency, cache, and build names are filtered by default." \
		"Normal Git roots also respect local Git ignore rules; Git never contacts remotes." \
		"Exit codes: 0 complete, 1 error, 64 usage, 69 missing dependency."
}

case "${1:-}" in
--summary)
	printf "Preview or create a filtered, read-only project tar.gz archive.\n"
	exit 0
	;;
esac

for mantle_archive_argument in "$@"; do
	[[ "${mantle_archive_argument}" != "--" ]] || break
	if [[ "${mantle_archive_argument}" == "--help" || "${mantle_archive_argument}" == "-h" ]]; then
		mantle_archive_usage
		exit 0
	fi
done

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi
if ! command -v python3 >/dev/null 2>&1; then
	printf "[mantle:error] project archives require Python 3.9 or newer (python3).\n" >&2
	exit 69
fi
exec python3 "${MANTLE_ROOT}/libexec/mantle/archive.py" "$@"
