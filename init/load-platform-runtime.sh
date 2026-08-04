#!/usr/bin/env bash
# shellcheck shell=bash
#
# Load the active operating-system adapter after portable environment modules.

if [[ -n "${BASH_VERSION:-}" ]]; then
	if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
		printf "[mantle:error] init/load-platform-runtime.sh is internal and must be sourced\n" >&2
		exit 64
	fi
fi

if [[ "${MANTLE_PLATFORM_RUNTIME_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] init/load-platform-runtime.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

__mantle_platform_family="${MANTLE_OS_FAMILY:-}"

if [[ -z "${__mantle_platform_family}" ]] &&
	command -v mantle_os_detect >/dev/null 2>&1; then
	__mantle_platform_family="$(mantle_os_detect 2>/dev/null)"
fi

if [[ -z "${__mantle_platform_family}" ]]; then
	case "$(uname -s 2>/dev/null)" in
	Darwin)
		__mantle_platform_family="darwin"
		;;
	Linux)
		__mantle_platform_family="linux"
		;;
	CYGWIN* | MINGW* | MSYS*)
		__mantle_platform_family="windows"
		;;
	*)
		__mantle_platform_family="unknown"
		;;
	esac
fi

case "${__mantle_platform_family}" in
darwin | macos)
	__mantle_platform_family="darwin"
	;;
linux | wsl)
	__mantle_platform_family="linux"
	;;
windows | cygwin | mingw | msys)
	__mantle_platform_family="windows"
	;;
*)
	__mantle_platform_family="unknown"
	;;
esac

MANTLE_OS_FAMILY="${__mantle_platform_family}"
export MANTLE_OS_FAMILY

if [[ "${__mantle_platform_family}" == "unknown" ]]; then
	MANTLE_PLATFORM_RUNTIME="none"
	MANTLE_PLATFORM_RUNTIME_LOADED="1"
	export MANTLE_PLATFORM_RUNTIME

	if [[ "${MANTLE_DEBUG:-0}" == "1" ]]; then
		printf "[mantle:debug] no platform runtime is available for this operating system\n" >&2
	fi

	unset __mantle_platform_family
	return 0
fi

__mantle_platform_runtime_path="${MANTLE_ROOT}/platforms/${__mantle_platform_family}/runtime.sh"

if [[ ! -f "${__mantle_platform_runtime_path}" ||
	! -r "${__mantle_platform_runtime_path}" ]]; then
	printf "[mantle:error] platform runtime is missing or unreadable: %s\n" \
		"${__mantle_platform_runtime_path}" >&2
	unset __mantle_platform_family
	unset __mantle_platform_runtime_path
	return 1
fi

# shellcheck disable=SC1090
source "${__mantle_platform_runtime_path}"
__mantle_platform_runtime_status=$?

if ((__mantle_platform_runtime_status != 0)); then
	printf "[mantle:error] platform runtime failed with status %d: %s\n" \
		"${__mantle_platform_runtime_status}" "${__mantle_platform_runtime_path}" >&2
	MANTLE_LAST_ERROR_STATUS="${__mantle_platform_runtime_status}"
	unset __mantle_platform_family
	unset __mantle_platform_runtime_path
	unset __mantle_platform_runtime_status
	return "${MANTLE_LAST_ERROR_STATUS}"
fi

MANTLE_PLATFORM_RUNTIME="${__mantle_platform_family}"
MANTLE_PLATFORM_RUNTIME_LOADED="1"
export MANTLE_PLATFORM_RUNTIME

unset __mantle_platform_family
unset __mantle_platform_runtime_path
unset __mantle_platform_runtime_status

return 0
