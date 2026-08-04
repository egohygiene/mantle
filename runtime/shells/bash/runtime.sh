#!/usr/bin/env bash
# shellcheck shell=bash
#
# Load Mantle's Bash-specific introspection and utility libraries.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] runtime/shells/bash/runtime.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_RUNTIME_BASH_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${BASH_VERSION:-}" ]]; then
	printf "[mantle:error] Bash runtime was sourced by a non-Bash shell\n" >&2
	return 64
fi

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] runtime/shells/bash/runtime.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

if [[ "${MANTLE_RUNTIME_SHARED_LOADED:-0}" != "1" ||
	"${MANTLE_RUNTIME_POSIX_LOADED:-0}" != "1" ]]; then
	printf "[mantle:error] Bash runtime requires the shared and POSIX runtimes\n" >&2
	return 1
fi

__mantle_bash_runtime_libraries=(
	"${MANTLE_ROOT}/lib/core/bash.sh"
	"${MANTLE_ROOT}/lib/bash/array.sh"
	"${MANTLE_ROOT}/lib/bash/collection.sh"
	"${MANTLE_ROOT}/lib/bash/date.sh"
	"${MANTLE_ROOT}/lib/bash/debug.sh"
	"${MANTLE_ROOT}/lib/bash/file.sh"
	"${MANTLE_ROOT}/lib/bash/format.sh"
	"${MANTLE_ROOT}/lib/bash/interaction.sh"
	"${MANTLE_ROOT}/lib/bash/json.sh"
	"${MANTLE_ROOT}/lib/bash/misc.sh"
	"${MANTLE_ROOT}/lib/bash/string.sh"
	"${MANTLE_ROOT}/lib/bash/terminal.sh"
	"${MANTLE_ROOT}/lib/bash/validation.sh"
	"${MANTLE_ROOT}/lib/bash/variable.sh"
)

__mantle_bash_runtime_status=0

for __mantle_bash_runtime_path in "${__mantle_bash_runtime_libraries[@]}"; do
	if [[ ! -f "${__mantle_bash_runtime_path}" ||
		! -r "${__mantle_bash_runtime_path}" ]]; then
		printf "[mantle:error] Bash runtime library is missing or unreadable: %s\n" \
			"${__mantle_bash_runtime_path}" >&2
		__mantle_bash_runtime_status=1
		break
	fi

	# shellcheck disable=SC1090
	source "${__mantle_bash_runtime_path}"
	__mantle_bash_runtime_status=$?

	if ((__mantle_bash_runtime_status != 0)); then
		printf "[mantle:error] Bash runtime library failed with status %d: %s\n" \
			"${__mantle_bash_runtime_status}" "${__mantle_bash_runtime_path}" >&2
		break
	fi
done

unset __mantle_bash_runtime_libraries
unset __mantle_bash_runtime_path

if ((__mantle_bash_runtime_status == 0)); then
	MANTLE_RUNTIME_BASH_LOADED="1"
	unset __mantle_bash_runtime_status
	return 0
fi

MANTLE_LAST_ERROR_STATUS="${__mantle_bash_runtime_status}"
unset __mantle_bash_runtime_status

return "${MANTLE_LAST_ERROR_STATUS}"
