#!/usr/bin/env bash
# shellcheck shell=bash
# Install operating-system packages without implicit privilege escalation.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/native-package.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_NATIVE_PACKAGE_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Print a shell-escaped native package-manager command.
# @arg $@ string Command and arguments.
__mantle_install_native_package_print_command() {
	local argument=""

	printf "+"
	for argument in "$@"; do
		printf " %q" "${argument}"
	done
	printf "\n"
}

# @description Determine whether a package manager normally requires root privileges.
# @arg $1 string Package-manager name.
# @exitcode 0 The manager normally requires root.
# @exitcode 1 The manager supports user-level execution.
__mantle_install_native_package_requires_root() {
	case "${1:-}" in
	apk | apt | dnf | pacman | yum | zypper) return 0 ;;
	*) return 1 ;;
	esac
}

# @description Print the shared native-package installer usage.
mantle_install_native_package_usage() {
	local tool_name="${MANTLE_INSTALLER_NAME:-${MANTLE_INSTALL_TOOL_NAME:-package}}"

	printf "Usage: mantle install %s [--manager MANAGER] [--update-index] [--force] [--dry-run] [--help]\n" "${tool_name}"
}

# @description Install a tool or library with the detected operating-system package manager.
# @arg $@ string Shared native-package installer command-line arguments.
# @exitcode 64 Configuration or command-line usage is invalid.
# @exitcode 69 No configured package manager is available.
# @exitcode 77 The selected package manager requires explicit root execution.
mantle_install_native_package_main() {
	local requested_manager="${MANTLE_INSTALL_PACKAGE_MANAGER:-}"
	local update_index="0"
	local force_install="0"
	local dry_run="0"
	local manager=""
	local package_variable=""
	local verify_command=""
	local all_commands_available="1"
	local -a packages=()
	local -a verify_commands=()
	local -a update_command=()
	local -a install_command=()

	if [[ -z "${MANTLE_INSTALL_TOOL_NAME:-}" ]]; then
		mantle_log_error "Native-package installer metadata is incomplete"
		return 64
	fi

	while (($# > 0)); do
		case "$1" in
		--manager)
			if (($# < 2)) || [[ -z "${2:-}" ]]; then
				mantle_log_error "--manager requires a value"
				return 64
			fi
			requested_manager="$2"
			shift 2
			;;
		--update-index)
			update_index="1"
			shift
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
			mantle_install_native_package_usage
			return 0
			;;
		*)
			mantle_log_error "Unknown argument: $1"
			mantle_install_native_package_usage >&2
			return 64
			;;
		esac
	done

	manager="$(mantle_install_package_manager_detect "${requested_manager}")" || return $?
	case "${manager}" in
	apk) package_variable="MANTLE_INSTALL_PACKAGES_APK" ;;
	apt) package_variable="MANTLE_INSTALL_PACKAGES_APT" ;;
	brew)
		if declare -p MANTLE_INSTALL_PACKAGES_BREW_CASK >/dev/null 2>&1; then
			package_variable="MANTLE_INSTALL_PACKAGES_BREW_CASK"
		else
			package_variable="MANTLE_INSTALL_PACKAGES_BREW"
		fi
		;;
	dnf) package_variable="MANTLE_INSTALL_PACKAGES_DNF" ;;
	pacman) package_variable="MANTLE_INSTALL_PACKAGES_PACMAN" ;;
	yum) package_variable="MANTLE_INSTALL_PACKAGES_YUM" ;;
	zypper) package_variable="MANTLE_INSTALL_PACKAGES_ZYPPER" ;;
	*)
		mantle_log_error "Package installation is not implemented for ${manager}"
		return 69
		;;
	esac
	case "${package_variable}" in
	MANTLE_INSTALL_PACKAGES_APK)
		declare -p MANTLE_INSTALL_PACKAGES_APK >/dev/null 2>&1 && packages=("${MANTLE_INSTALL_PACKAGES_APK[@]}")
		;;
	MANTLE_INSTALL_PACKAGES_APT)
		declare -p MANTLE_INSTALL_PACKAGES_APT >/dev/null 2>&1 && packages=("${MANTLE_INSTALL_PACKAGES_APT[@]}")
		;;
	MANTLE_INSTALL_PACKAGES_BREW)
		declare -p MANTLE_INSTALL_PACKAGES_BREW >/dev/null 2>&1 && packages=("${MANTLE_INSTALL_PACKAGES_BREW[@]}")
		;;
	MANTLE_INSTALL_PACKAGES_BREW_CASK)
		declare -p MANTLE_INSTALL_PACKAGES_BREW_CASK >/dev/null 2>&1 && packages=("${MANTLE_INSTALL_PACKAGES_BREW_CASK[@]}")
		;;
	MANTLE_INSTALL_PACKAGES_DNF)
		declare -p MANTLE_INSTALL_PACKAGES_DNF >/dev/null 2>&1 && packages=("${MANTLE_INSTALL_PACKAGES_DNF[@]}")
		;;
	MANTLE_INSTALL_PACKAGES_PACMAN)
		declare -p MANTLE_INSTALL_PACKAGES_PACMAN >/dev/null 2>&1 && packages=("${MANTLE_INSTALL_PACKAGES_PACMAN[@]}")
		;;
	MANTLE_INSTALL_PACKAGES_YUM)
		declare -p MANTLE_INSTALL_PACKAGES_YUM >/dev/null 2>&1 && packages=("${MANTLE_INSTALL_PACKAGES_YUM[@]}")
		;;
	MANTLE_INSTALL_PACKAGES_ZYPPER)
		declare -p MANTLE_INSTALL_PACKAGES_ZYPPER >/dev/null 2>&1 && packages=("${MANTLE_INSTALL_PACKAGES_ZYPPER[@]}")
		;;
	esac
	if ((${#packages[@]} == 0)); then
		mantle_log_error "${MANTLE_INSTALL_TOOL_NAME} has no package mapping for ${manager}"
		return 69
	fi

	if declare -p MANTLE_INSTALL_NATIVE_VERIFY_COMMANDS >/dev/null 2>&1; then
		verify_commands=("${MANTLE_INSTALL_NATIVE_VERIFY_COMMANDS[@]}")
		for verify_command in "${verify_commands[@]}"; do
			if ! mantle_guard_has_command "${verify_command}"; then
				all_commands_available="0"
			fi
		done
	fi
	if [[ "${all_commands_available}" == "1" && "${force_install}" == "0" ]] &&
		((${#verify_commands[@]} > 0)); then
		mantle_log_success "${MANTLE_INSTALL_TOOL_NAME} is already available"
		return 0
	fi

	case "${manager}" in
	apk)
		install_command=(apk add --no-cache "${packages[@]}")
		if [[ "${update_index}" == "1" ]]; then update_command=(apk update); fi
		;;
	apt)
		install_command=(apt-get install --yes --no-install-recommends "${packages[@]}")
		if [[ "${update_index}" == "1" ]]; then update_command=(apt-get update); fi
		;;
	brew)
		if [[ "${package_variable}" == "MANTLE_INSTALL_PACKAGES_BREW_CASK" ]]; then
			install_command=(brew install --cask "${packages[@]}")
		else
			install_command=(brew install "${packages[@]}")
		fi
		if [[ "${force_install}" == "1" ]]; then
			install_command[1]="reinstall"
		fi
		if [[ "${update_index}" == "1" ]]; then update_command=(brew update); fi
		;;
	dnf)
		install_command=(dnf install --assumeyes "${packages[@]}")
		if [[ "${update_index}" == "1" ]]; then update_command=(dnf makecache); fi
		;;
	pacman)
		install_command=(pacman --sync --needed --noconfirm "${packages[@]}")
		if [[ "${update_index}" == "1" ]]; then update_command=(pacman --sync --refresh); fi
		;;
	yum)
		install_command=(yum install --assumeyes "${packages[@]}")
		if [[ "${update_index}" == "1" ]]; then update_command=(yum makecache); fi
		;;
	zypper)
		install_command=(zypper --non-interactive install "${packages[@]}")
		if [[ "${update_index}" == "1" ]]; then update_command=(zypper --non-interactive refresh); fi
		;;
	esac

	if [[ "${dry_run}" == "1" ]]; then
		printf "tool: %s\n" "${MANTLE_INSTALL_TOOL_NAME}"
		printf "manager: %s\n" "${manager}"
		if ((${#update_command[@]} > 0)); then
			__mantle_install_native_package_print_command "${update_command[@]}"
		fi
		__mantle_install_native_package_print_command "${install_command[@]}"
		return 0
	fi
	if __mantle_install_native_package_requires_root "${manager}" && ((EUID != 0)); then
		mantle_log_error "${manager} package installation requires explicit root execution"
		mantle_log_error "Review the dry run, then rerun this installer with sudo"
		return 77
	fi

	if ((${#update_command[@]} > 0)); then
		"${update_command[@]}" || return $?
	fi
	mantle_log_info "Installing ${MANTLE_INSTALL_TOOL_NAME} with ${manager}"
	"${install_command[@]}" || return $?

	for verify_command in "${verify_commands[@]}"; do
		if ! mantle_guard_has_command "${verify_command}"; then
			mantle_log_error "Expected command is unavailable after installation: ${verify_command}"
			return 1
		fi
	done
	mantle_log_success "Installed ${MANTLE_INSTALL_TOOL_NAME}"
}

MANTLE_INSTALL_NATIVE_PACKAGE_LIBRARY_LOADED="1"

return 0
