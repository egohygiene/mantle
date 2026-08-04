#!/usr/bin/env bash
# shellcheck shell=bash
# Report the current Mantle version without requiring initialization.

set -o errexit
set -o nounset
set -o pipefail

# @description Print mantle version usage.
mantle_version_usage() {
	printf "%s\n" \
		"Usage: mantle version [--short] [--help]" \
		"" \
		"Resolve the version from MANTLE_VERSION, VERSION, or Git metadata."
}

# @description Resolve the best available Mantle version identifier.
# @stdout Version identifier or development fallback.
mantle_version_resolve() {
	local resolved_version="${MANTLE_VERSION:-}"
	local version_file="${MANTLE_ROOT}/VERSION"

	if [[ -n "${resolved_version}" ]]; then
		printf "%s\n" "${resolved_version}"
		return 0
	fi

	if [[ -r "${version_file}" ]]; then
		IFS= read -r resolved_version <"${version_file}" || true
		if [[ -n "${resolved_version}" ]]; then
			printf "%s\n" "${resolved_version}"
			return 0
		fi
	fi

	if command -v git >/dev/null 2>&1 && [[ -e "${MANTLE_ROOT}/.git" ]]; then
		resolved_version="$(git -C "${MANTLE_ROOT}" describe --tags --always --dirty 2>/dev/null)" || true
		if [[ -n "${resolved_version}" ]]; then
			printf "%s\n" "${resolved_version}"
			return 0
		fi
	fi

	printf "development\n"
}

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

mantle_version_short="0"
while (($# > 0)); do
	case "$1" in
		--summary)
			printf "Show the installed Mantle version.\n"
			exit 0
			;;
		--short)
			mantle_version_short="1"
			shift
			;;
		--help | -h)
			mantle_version_usage
			exit 0
			;;
		*)
			printf "[mantle:error] unknown version option: %s\n" "$1" >&2
			mantle_version_usage >&2
			exit 64
			;;
	esac
done

mantle_resolved_version="$(mantle_version_resolve)"
if [[ "${mantle_version_short}" == "1" ]]; then
	printf "%s\n" "${mantle_resolved_version}"
else
	printf "mantle %s\n" "${mantle_resolved_version}"
fi
