#!/usr/bin/env bash
# shellcheck shell=bash
# Transactionally load Mantle's Bash-based installer runtime.

if [[ -z "${BASH_VERSION:-}" ]]; then
	printf "[mantle:error] lib/install/runtime.sh requires Bash\n" >&2
	return 64 2>/dev/null
fi

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/runtime.sh is internal and must be sourced\n" >&2
	exit 64
fi

case "${MANTLE_INSTALL_RUNTIME_STATE:-uninitialized}" in
	initialized)
		return 0
		;;
	initializing)
		printf "[mantle:error] recursive installer-runtime initialization detected\n" >&2
		return 70
		;;
esac

# @description Resolve Mantle's root and transactionally source the installer runtime libraries.
# @exitcode 0 Every required library loaded successfully.
# @exitcode 1 Root resolution or a required library load failed.
__mantle_install_runtime_entrypoint() {
	local source_path="${BASH_SOURCE[0]}"
	local resolved_root=""
	local library_file=""
	local library_path=""
	local runtime_status=0
	local -a core_files=(
		"colors.sh"
		"guards.sh"
		"logging.sh"
		"os.sh"
	)
	local -a install_files=(
		"platform.sh"
		"package-manager.sh"
		"download.sh"
		"checksum.sh"
		"archive.sh"
		"filesystem.sh"
		"github.sh"
		"native-package.sh"
		"python-tool.sh"
	)

	MANTLE_INSTALL_RUNTIME_STATE="initializing"
	resolved_root="$(builtin cd "$(dirname "${source_path}")/../.." 2>/dev/null && pwd -P)" || true
	if [[ -z "${resolved_root}" ]]; then
		printf "[mantle:error] unable to resolve the Mantle root from installer runtime\n" >&2
		runtime_status=1
	elif [[ -n "${MANTLE_ROOT:-}" && "${MANTLE_ROOT}" != "${resolved_root}" ]]; then
		printf "[mantle:error] MANTLE_ROOT does not match the installer runtime location\n" >&2
		runtime_status=1
	else
		MANTLE_ROOT="${resolved_root}"
		export MANTLE_ROOT
	fi

	if ((runtime_status == 0)); then
		for library_file in "${core_files[@]}"; do
			library_path="${MANTLE_ROOT}/lib/core/${library_file}"
			if [[ ! -r "${library_path}" ]]; then
				printf "[mantle:error] missing required core library: %s\n" "${library_path}" >&2
				runtime_status=1
				break
			fi
			# shellcheck disable=SC1090
			source "${library_path}" || {
				runtime_status=$?
				break
			}
		done
	fi

	if ((runtime_status == 0)); then
		for library_file in "${install_files[@]}"; do
			library_path="${MANTLE_ROOT}/lib/install/${library_file}"
			if [[ ! -r "${library_path}" ]]; then
				mantle_log_error "Missing required install library: ${library_path}"
				runtime_status=1
				break
			fi
			# shellcheck disable=SC1090
			source "${library_path}" || {
				runtime_status=$?
				break
			}
		done
	fi

	if ((runtime_status == 0)); then
		MANTLE_INSTALL_RUNTIME_STATE="initialized"
	else
		MANTLE_INSTALL_RUNTIME_STATE="failed"
	fi

	unset -f __mantle_install_runtime_entrypoint
	return "${runtime_status}"
}

__mantle_install_runtime_entrypoint
return $?
