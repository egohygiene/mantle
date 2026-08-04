#!/usr/bin/env bash
# shellcheck shell=bash
#
# Define Mantle's opt-in extension loader.

if [[ -n "${BASH_VERSION:-}" ]]; then
	if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
		printf "[mantle:error] init/load-extensions.sh is internal and must be sourced\n" >&2
		exit 64
	fi
fi

if [[ "${MANTLE_EXTENSION_LOADER_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] init/load-extensions.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

# @description Load one optional Mantle library from lib/extensions.
# The extension is sourced at most once after a successful load. A failed load
# remains retryable.
#
# @arg $1 string Extension name without a file extension.
# @exitcode 0 The extension was loaded or had already been loaded.
# @exitcode 1 The name was invalid, the file was unavailable, or sourcing failed.
mantle_load_extension() {
	local extension_name="${1:-}"
	local extension_path=""
	local extension_status=0

	if (($# != 1)) || [[ -z "${extension_name}" ]]; then
		printf "[mantle:error] mantle_load_extension requires exactly one extension name\n" >&2
		return 1
	fi

	case "${extension_name}" in
	*[!A-Za-z0-9_-]*)
		printf "[mantle:error] invalid extension name: %s\n" "${extension_name}" >&2
		return 1
		;;
	esac

	case ":${MANTLE_LOADED_EXTENSIONS:-}:" in
	*":${extension_name}:"*)
		return 0
		;;
	esac

	extension_path="${MANTLE_ROOT}/lib/extensions/${extension_name}.sh"

	if [[ ! -f "${extension_path}" || ! -r "${extension_path}" ]]; then
		printf "[mantle:error] extension is missing or unreadable: %s\n" \
			"${extension_path}" >&2
		return 1
	fi

	# shellcheck disable=SC1090
	source "${extension_path}"
	extension_status=$?

	if ((extension_status != 0)); then
		printf "[mantle:error] extension failed with status %d: %s\n" \
			"${extension_status}" "${extension_path}" >&2
		return "${extension_status}"
	fi

	if [[ -n "${MANTLE_LOADED_EXTENSIONS:-}" ]]; then
		MANTLE_LOADED_EXTENSIONS="${MANTLE_LOADED_EXTENSIONS}:${extension_name}"
	else
		MANTLE_LOADED_EXTENSIONS="${extension_name}"
	fi

	return 0
}

MANTLE_EXTENSION_LOADER_LOADED="1"
