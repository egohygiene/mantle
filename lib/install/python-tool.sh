#!/usr/bin/env bash
# shellcheck shell=bash
# Install isolated Python command-line applications with uv or pipx.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/python-tool.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_PYTHON_TOOL_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Confirm that MANTLE_INSTALL_PYTHON_EXECUTABLES is an indexed Bash array.
# @exitcode 0 The variable exists and is indexed.
# @exitcode 1 The variable is absent or has another type.
__mantle_install_python_tool_array_is_indexed() {
	local declaration=""

	declaration="$(declare -p MANTLE_INSTALL_PYTHON_EXECUTABLES 2>/dev/null)" || return 1
	[[ "${declaration}" =~ ^declare\ -[[:alpha:]]*a[[:alpha:]]*\ MANTLE_INSTALL_PYTHON_EXECUTABLES= ]]
}

# @description Print a shell-escaped isolated Python installer command.
# @arg $@ string Command and arguments.
__mantle_install_python_tool_print_command() {
	local argument=""

	printf "+"
	for argument in "$@"; do
		printf " %q" "${argument}"
	done
	printf "\n"
}

# @description Print the shared Python-tool installer usage.
mantle_install_python_tool_usage() {
	local tool_name="${MANTLE_INSTALLER_NAME:-${MANTLE_INSTALL_TOOL_NAME:-python-tool}}"

	printf "Usage: mantle install %s [--version VERSION] [--manager auto|uv|pipx] [--force] [--dry-run] [--help]\n" "${tool_name}"
}

# @description Install an isolated Python CLI using declarative package metadata.
# @arg $@ string Shared Python-tool installer command-line arguments.
# @exitcode 64 Configuration or command-line usage is invalid.
# @exitcode 69 Neither uv nor pipx is available.
mantle_install_python_tool_main() {
	local package_name="${MANTLE_INSTALL_PYTHON_PACKAGE:-}"
	local requested_version="${MANTLE_INSTALL_VERSION:-}"
	local requested_manager="${MANTLE_INSTALL_PYTHON_MANAGER:-auto}"
	local force_install="0"
	local dry_run="0"
	local package_specification=""
	local manager=""
	local executable_name=""
	local executable_missing="0"
	local -a executable_names=()
	local -a install_command=()

	if [[ -z "${MANTLE_INSTALL_TOOL_NAME:-}" || -z "${package_name}" ]]; then
		mantle_log_error "Python installer metadata is incomplete"
		return 64
	fi
	if ! __mantle_install_python_tool_array_is_indexed; then
		mantle_log_error "MANTLE_INSTALL_PYTHON_EXECUTABLES must be a nonempty indexed array"
		return 64
	fi
	executable_names=("${MANTLE_INSTALL_PYTHON_EXECUTABLES[@]}")
	if ((${#executable_names[@]} == 0)); then
		mantle_log_error "At least one Python executable must be configured"
		return 64
	fi

	while (($# > 0)); do
		case "$1" in
			--version)
				if (($# < 2)) || [[ -z "${2:-}" ]]; then
					mantle_log_error "--version requires a value"
					return 64
				fi
				requested_version="$2"
				shift 2
				;;
			--manager)
				if (($# < 2)) || [[ -z "${2:-}" ]]; then
					mantle_log_error "--manager requires a value"
					return 64
				fi
				requested_manager="$2"
				shift 2
				;;
			--force)
				force_install="1"
				shift
				;;
			--dry-run)
				dry_run="1"
				shift
				;;
			--help | -h)
				mantle_install_python_tool_usage
				return 0
				;;
			*)
				mantle_log_error "Unknown argument: $1"
				mantle_install_python_tool_usage >&2
				return 64
				;;
		esac
	done

	case "${requested_manager}" in
		auto)
			if mantle_guard_has_command uv; then
				manager="uv"
			elif mantle_guard_has_command pipx; then
				manager="pipx"
			else
				mantle_log_error "Installing ${MANTLE_INSTALL_TOOL_NAME} requires uv or pipx"
				return 69
			fi
			;;
		uv | pipx)
			manager="${requested_manager}"
			if ! mantle_guard_has_command "${manager}"; then
				mantle_log_error "Requested Python tool manager is unavailable: ${manager}"
				return 69
			fi
			;;
		*)
			mantle_log_error "Unsupported Python tool manager: ${requested_manager}"
			return 64
			;;
	esac

	for executable_name in "${executable_names[@]}"; do
		if ! mantle_guard_has_command "${executable_name}"; then
			executable_missing="1"
		fi
	done
	if [[ "${executable_missing}" == "0" && -z "${requested_version}" && "${force_install}" == "0" ]]; then
		mantle_log_success "${MANTLE_INSTALL_TOOL_NAME} is already available"
		return 0
	fi

	package_specification="${package_name}"
	if [[ -n "${requested_version}" ]]; then
		package_specification="${package_name}==${requested_version}"
		force_install="1"
	fi

	case "${manager}" in
		uv)
			install_command=(uv tool install)
			if [[ "${force_install}" == "1" ]]; then
				install_command+=("--force")
			fi
			install_command+=("${package_specification}")
			;;
		pipx)
			install_command=(pipx install)
			if [[ "${force_install}" == "1" ]]; then
				install_command+=("--force")
			fi
			install_command+=("${package_specification}")
			;;
	esac

	if [[ "${dry_run}" == "1" ]]; then
		printf "tool: %s\n" "${MANTLE_INSTALL_TOOL_NAME}"
		printf "package: %s\n" "${package_specification}"
		printf "manager: %s\n" "${manager}"
		__mantle_install_python_tool_print_command "${install_command[@]}"
		return 0
	fi

	mantle_log_info "Installing ${package_specification} with ${manager}"
	"${install_command[@]}" || return $?

	for executable_name in "${executable_names[@]}"; do
		if ! mantle_guard_has_command "${executable_name}"; then
			mantle_log_error "Expected executable is unavailable after installation: ${executable_name}"
			return 1
		fi
	done
	mantle_log_success "Installed ${MANTLE_INSTALL_TOOL_NAME}"
}

MANTLE_INSTALL_PYTHON_TOOL_LIBRARY_LOADED="1"

return 0
