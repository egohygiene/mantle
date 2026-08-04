#!/bin/sh
# shellcheck shell=sh
#
# Load the shell-neutral core libraries required by every Mantle runtime.

if [ "${MANTLE_RUNTIME_SHARED_LOADED:-0}" = "1" ]; then
	return 0
fi

if [ -z "${MANTLE_ROOT:-}" ]; then
	printf "[mantle:error] runtime/shared/runtime.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

__mantle_shared_runtime_status=0

for __mantle_shared_runtime_library in \
	colors.sh \
	logging.sh \
	guards.sh \
	core.sh \
	time.sh; do
	__mantle_shared_runtime_path="${MANTLE_ROOT}/lib/core/${__mantle_shared_runtime_library}"

	if [ ! -f "${__mantle_shared_runtime_path}" ] ||
		[ ! -r "${__mantle_shared_runtime_path}" ]; then
		printf "[mantle:error] shared runtime library is missing or unreadable: %s\n" \
			"${__mantle_shared_runtime_path}" >&2
		__mantle_shared_runtime_status=1
		break
	fi

	# shellcheck disable=SC1090
	. "${__mantle_shared_runtime_path}"
	__mantle_shared_runtime_status=$?

	if [ "${__mantle_shared_runtime_status}" -ne 0 ]; then
		printf "[mantle:error] shared runtime library failed with status %d: %s\n" \
			"${__mantle_shared_runtime_status}" "${__mantle_shared_runtime_path}" >&2
		break
	fi
done

unset __mantle_shared_runtime_library
unset __mantle_shared_runtime_path

if [ "${__mantle_shared_runtime_status}" -eq 0 ]; then
	MANTLE_RUNTIME_SHARED_LOADED="1"
	unset __mantle_shared_runtime_status
	return 0
fi

MANTLE_LAST_ERROR_STATUS="${__mantle_shared_runtime_status}"
unset __mantle_shared_runtime_status

return "${MANTLE_LAST_ERROR_STATUS}"
