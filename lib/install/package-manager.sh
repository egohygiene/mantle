#!/usr/bin/env bash
# shellcheck shell=bash
#
# Detect the host's preferred native package manager without installing packages.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/package-manager.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_PACKAGE_MANAGER_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_install_package_manager_command() {
	case "${1:-}" in
		apk) printf "apk\n" ;;
		apt) printf "apt-get\n" ;;
		brew) printf "brew\n" ;;
		choco) printf "choco\n" ;;
		dnf) printf "dnf\n" ;;
		nix) printf "nix-env\n" ;;
		pacman) printf "pacman\n" ;;
		scoop) printf "scoop\n" ;;
		winget) printf "winget\n" ;;
		yum) printf "yum\n" ;;
		zypper) printf "zypper\n" ;;
		*) return 1 ;;
	esac
}

__mantle_install_package_manager_is_available() {
	local package_manager_command=""

	package_manager_command="$(__mantle_install_package_manager_command "${1:-}")" || return 1
	mantle_guard_has_command "${package_manager_command}"
}

# @description Detect the preferred available package manager for the host OS.
# @arg $1 string Optional explicit manager; MANTLE_INSTALL_PACKAGE_MANAGER is the fallback override.
# @stdout Package-manager identifier such as brew, apt, dnf, or winget.
# @exitcode 1 No supported package manager is available.
# @exitcode 64 Usage is invalid or an explicit manager is unsupported.
mantle_install_package_manager_detect() {
	local requested_manager="${1:-${MANTLE_INSTALL_PACKAGE_MANAGER:-}}"
	local platform_family="${MANTLE_OS_FAMILY:-unknown}"
	local package_manager=""
	local -a candidates=()

	if (($# > 1)); then
		return 64
	fi

	if [[ -n "${requested_manager}" ]]; then
		if ! __mantle_install_package_manager_command "${requested_manager}" >/dev/null; then
			mantle_log_error "Unsupported package manager: ${requested_manager}"
			return 64
		fi
		if ! __mantle_install_package_manager_is_available "${requested_manager}"; then
			mantle_log_error "Requested package manager is unavailable: ${requested_manager}"
			return 1
		fi
		printf "%s\n" "${requested_manager}"
		return 0
	fi

	case "${platform_family}" in
		darwin)
			candidates=(brew nix)
			;;
		linux)
			candidates=(apt dnf yum pacman zypper apk nix brew)
			;;
		windows)
			candidates=(winget scoop choco)
			;;
		*)
			candidates=(brew apt dnf yum pacman zypper apk nix winget scoop choco)
			;;
	esac

	for package_manager in "${candidates[@]}"; do
		if __mantle_install_package_manager_is_available "${package_manager}"; then
			printf "%s\n" "${package_manager}"
			return 0
		fi
	done

	printf "unknown\n"
	return 1
}

MANTLE_INSTALL_PACKAGE_MANAGER_LIBRARY_LOADED="1"

return 0
