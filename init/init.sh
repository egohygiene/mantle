#!/usr/bin/env bash
# shellcheck shell=bash
#
# Canonical Mantle initialization orchestrator.
#
# This file is internal and must be sourced through the repository-level
# .shellrc entrypoint. It coordinates required loaders without changing shell
# options, the working directory, or the caller's IFS.

if [[ -n "${BASH_VERSION:-}" ]]; then
	if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
		printf "[mantle:error] init/init.sh is internal and must be sourced through .shellrc\n" >&2
		exit 64
	fi
fi

if [[ "${MANTLE_INIT_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] init/init.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

__mantle_init_source_required() {
	local source_path="${1:-}"
	local source_label="${2:-required initialization component}"
	local source_status=0

	if [[ -z "${source_path}" || ! -f "${source_path}" || ! -r "${source_path}" ]]; then
		printf "[mantle:error] missing or unreadable %s: %s\n" \
			"${source_label}" "${source_path:-<empty path>}" >&2
		return 1
	fi

	# shellcheck disable=SC1090
	source "${source_path}"
	source_status=$?

	if ((source_status != 0)); then
		printf "[mantle:error] %s failed with status %d: %s\n" \
			"${source_label}" "${source_status}" "${source_path}" >&2
	fi

	return "${source_status}"
}

__mantle_init_status=0

__mantle_init_source_required \
	"${MANTLE_ROOT}/init/load-core.sh" \
	"core loader" || __mantle_init_status=$?

if ((__mantle_init_status == 0)); then
	__mantle_init_source_required \
		"${MANTLE_ROOT}/init/load-extensions.sh" \
		"extension loader" || __mantle_init_status=$?
fi

if ((__mantle_init_status == 0)); then
	__mantle_init_source_required \
		"${MANTLE_ROOT}/lib/modules.sh" \
		"module loader" || __mantle_init_status=$?
fi

if ((__mantle_init_status == 0)); then
	__mantle_init_source_required \
		"${MANTLE_ROOT}/init/bootstrap.sh" \
		"environment bootstrap" || __mantle_init_status=$?
fi

if ((__mantle_init_status == 0)) && [[ "${MANTLE_DEBUG:-0}" == "1" ]]; then
	__mantle_init_debug_path="${MANTLE_ROOT}/init/debug.sh"

	if [[ -f "${__mantle_init_debug_path}" && -r "${__mantle_init_debug_path}" ]]; then
		__mantle_init_source_required \
			"${__mantle_init_debug_path}" \
			"debug initializer" || __mantle_init_status=$?
	else
		printf "[mantle:warn] debug initialization requested but unavailable: %s\n" \
			"${__mantle_init_debug_path}" >&2
	fi

	unset __mantle_init_debug_path
fi

unset -f __mantle_init_source_required

if ((__mantle_init_status == 0)); then
	MANTLE_INIT_LOADED="1"
	unset __mantle_init_status
	return 0
fi

MANTLE_LAST_ERROR_STATUS="${__mantle_init_status}"
unset __mantle_init_status

return "${MANTLE_LAST_ERROR_STATUS}"
