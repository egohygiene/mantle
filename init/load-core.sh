#!/usr/bin/env bash
# shellcheck shell=bash
#
# Load Mantle's required detection libraries and runtime adapters.
#
# Load order:
#   environment classification
#   operating-system and shell detection libraries
#   shared runtime
#   POSIX runtime baseline
#   active-shell runtime

if [[ -n "${BASH_VERSION:-}" ]]; then
	if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
		printf "[mantle:error] init/load-core.sh is internal and must be sourced\n" >&2
		exit 64
	fi
fi

if [[ "${MANTLE_CORE_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] init/load-core.sh: MANTLE_ROOT is not set\n" >&2
	return 1
fi

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
	MANTLE_RUNTIME_ENVIRONMENT="ci"
elif [[ -n "${CODESPACES:-}" ]]; then
	MANTLE_RUNTIME_ENVIRONMENT="codespaces"
elif [[ -n "${DEVCONTAINER:-}" || -n "${REMOTE_CONTAINERS:-}" ]]; then
	MANTLE_RUNTIME_ENVIRONMENT="devcontainer"
elif [[ "${CI:-}" == "1" || "${CI:-}" == "true" ]]; then
	MANTLE_RUNTIME_ENVIRONMENT="ci"
elif [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
	MANTLE_RUNTIME_ENVIRONMENT="wsl"
elif [[ -n "${container:-}" || -f "/.dockerenv" ]]; then
	MANTLE_RUNTIME_ENVIRONMENT="container"
else
	MANTLE_RUNTIME_ENVIRONMENT="local"
fi

export MANTLE_RUNTIME_ENVIRONMENT

__mantle_load_core_source_required() {
	local source_path="${1:-}"
	local source_label="${2:-runtime component}"
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

__mantle_load_core_status=0

__mantle_load_core_source_required \
	"${MANTLE_ROOT}/lib/core/os.sh" \
	"operating-system detection library" || __mantle_load_core_status=$?

if ((__mantle_load_core_status == 0)); then
	__mantle_load_core_source_required \
		"${MANTLE_ROOT}/lib/core/shell.sh" \
		"shell detection library" || __mantle_load_core_status=$?
fi

if [[ -z "${MANTLE_SHELL_NAME:-}" ]]; then
	if [[ -n "${BASH_VERSION:-}" ]]; then
		MANTLE_SHELL_NAME="bash"
	elif [[ -n "${ZSH_VERSION:-}" ]]; then
		MANTLE_SHELL_NAME="zsh"
	else
		MANTLE_SHELL_NAME="unknown"
	fi

	export MANTLE_SHELL_NAME
fi

if ((__mantle_load_core_status == 0)); then
	__mantle_load_core_source_required \
		"${MANTLE_ROOT}/runtime/shared/runtime.sh" \
		"shared runtime" || __mantle_load_core_status=$?
fi

if ((__mantle_load_core_status == 0)); then
	__mantle_load_core_source_required \
		"${MANTLE_ROOT}/runtime/shells/posix/runtime.sh" \
		"POSIX runtime" || __mantle_load_core_status=$?
fi

if ((__mantle_load_core_status == 0)); then
	case "${MANTLE_SHELL_NAME}" in
	bash | zsh)
		__mantle_load_core_source_required \
			"${MANTLE_ROOT}/runtime/shells/${MANTLE_SHELL_NAME}/runtime.sh" \
			"${MANTLE_SHELL_NAME} runtime" || __mantle_load_core_status=$?
		;;
	*)
		printf "[mantle:error] unsupported shell runtime requested: %s\n" \
			"${MANTLE_SHELL_NAME}" >&2
		__mantle_load_core_status=64
		;;
	esac
fi

unset -f __mantle_load_core_source_required

if ((__mantle_load_core_status == 0)); then
	MANTLE_CORE_LOADED="1"
	unset __mantle_load_core_status
	return 0
fi

MANTLE_LAST_ERROR_STATUS="${__mantle_load_core_status}"
unset __mantle_load_core_status

return "${MANTLE_LAST_ERROR_STATUS}"
