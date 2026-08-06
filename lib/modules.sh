#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide Mantle's deterministic, transactional environment-module loader.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/modules.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_MODULE_LOADER_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] lib/modules.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

: "${MANTLE_LOADED_MODULES:=}"
: "${MANTLE_LOADING_MODULES:=}"

# @description Load one Mantle environment module transactionally.
# A successfully loaded module is not sourced again. Failed loads remain
# retryable, and recursive module-loading cycles are rejected.
#
# @arg $1 string Module name without a file extension.
# @exitcode 0 The module loaded successfully or was already loaded.
# @exitcode 1 The module file was missing or unreadable.
# @exitcode 64 The module name or argument count was invalid.
# @exitcode 70 A recursive module-loading cycle was detected.
mantle_load_module() {
	local module_name="${1:-}"
	local module_path=""
	local module_status=0

	if (($# != 1)) || [[ -z "${module_name}" ]]; then
		printf "[mantle:error] mantle_load_module requires exactly one module name\n" >&2
		return 64
	fi

	case "${module_name}" in
	[!A-Za-z0-9]* | *[!A-Za-z0-9_-]*)
		printf "[mantle:error] invalid module name: %s\n" "${module_name}" >&2
		return 64
		;;
	esac

	case ":${MANTLE_LOADED_MODULES:-}:" in
	*":${module_name}:"*)
		return 0
		;;
	esac

	case ":${MANTLE_LOADING_MODULES:-}:" in
	*":${module_name}:"*)
		printf "[mantle:error] recursive module-loading cycle detected: %s\n" \
			"${module_name}" >&2
		return 70
		;;
	esac

	module_path="${MANTLE_ROOT}/modules/${module_name}.sh"

	if [[ ! -f "${module_path}" || ! -r "${module_path}" ]]; then
		printf "[mantle:error] module is missing or unreadable: %s\n" \
			"${module_path}" >&2
		return 1
	fi

	if [[ -n "${MANTLE_LOADING_MODULES}" ]]; then
		MANTLE_LOADING_MODULES="${MANTLE_LOADING_MODULES}:${module_name}"
	else
		MANTLE_LOADING_MODULES="${module_name}"
	fi

	# shellcheck disable=SC1090
	source "${module_path}"
	module_status=$?

	case "${MANTLE_LOADING_MODULES:-}" in
	"${module_name}")
		MANTLE_LOADING_MODULES=""
		;;
	*":${module_name}")
		MANTLE_LOADING_MODULES="${MANTLE_LOADING_MODULES%:"${module_name}"}"
		;;
	esac

	if ((module_status != 0)); then
		printf "[mantle:error] module failed with status %d: %s\n" \
			"${module_status}" "${module_path}" >&2
		return "${module_status}"
	fi

	if [[ -n "${MANTLE_LOADED_MODULES}" ]]; then
		MANTLE_LOADED_MODULES="${MANTLE_LOADED_MODULES}:${module_name}"
	else
		MANTLE_LOADED_MODULES="${module_name}"
	fi

	return 0
}

# @description Print successfully loaded module names, one per line.
# @stdout Zero or more module names in load order.
# @exitcode 0 Module state was listed.
# @exitcode 64 Unexpected arguments were provided.
mantle_list_loaded_modules() {
	local module_list="${MANTLE_LOADED_MODULES:-}"
	local module_name=""

	if (($# != 0)); then
		printf "[mantle:error] mantle_list_loaded_modules does not accept arguments\n" >&2
		return 64
	fi

	while [[ -n "${module_list}" ]]; do
		if [[ "${module_list}" == *:* ]]; then
			module_name="${module_list%%:*}"
			module_list="${module_list#*:}"
		else
			module_name="${module_list}"
			module_list=""
		fi

		printf "%s\n" "${module_name}"
	done
}

# @description Return whether a Mantle environment module has loaded.
#
# @arg $1 string Module name.
# @exitcode 0 The module has loaded successfully.
# @exitcode 1 The module has not loaded.
# @exitcode 64 The module name or argument count was invalid.
mantle_is_module_loaded() {
	local module_name="${1:-}"

	if (($# != 1)) || [[ -z "${module_name}" ]]; then
		printf "[mantle:error] mantle_is_module_loaded requires exactly one module name\n" >&2
		return 64
	fi

	case "${module_name}" in
	[!A-Za-z0-9]* | *[!A-Za-z0-9_-]*)
		printf "[mantle:error] invalid module name: %s\n" "${module_name}" >&2
		return 64
		;;
	esac

	case ":${MANTLE_LOADED_MODULES:-}:" in
	*":${module_name}:"*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

MANTLE_MODULE_LOADER_LOADED="1"

return 0
