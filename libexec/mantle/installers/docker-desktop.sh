#!/usr/bin/env bash
# shellcheck shell=bash
# Install Docker Desktop on macOS without launching a GUI installer implicitly.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

installer_dry_run="0"
installer_help="0"
installer_argument_index=0
declare -a installer_arguments=("$@")

while ((installer_argument_index < ${#installer_arguments[@]})); do
	installer_argument="${installer_arguments[installer_argument_index]}"
	case "${installer_argument}" in
		--manager)
			installer_argument_index=$((installer_argument_index + 1))
			if ((installer_argument_index >= ${#installer_arguments[@]})) ||
				[[ -z "${installer_arguments[installer_argument_index]}" ]]; then
				mantle_log_error "--manager requires a value"
				exit 64
			fi
			;;
		--force) ;;

		--dry-run)
			installer_dry_run="1"
			;;
		--help | -h)
			installer_help="1"
			;;
		*)
			mantle_log_error "Unknown argument: ${installer_argument}"
			printf "Usage: mantle install docker-desktop [--manager brew] [--force] [--dry-run] [--help]\n" >&2
			exit 64
			;;
	esac
	installer_argument_index=$((installer_argument_index + 1))
done

if [[ "${installer_help}" == "1" ]]; then
	printf "Usage: mantle install docker-desktop [--manager brew] [--force] [--dry-run] [--help]\n"
	exit 0
fi

if [[ "${installer_dry_run}" == "1" && "${MANTLE_OS_FAMILY:-unknown}" != "darwin" ]]; then
	printf "tool: docker-desktop\n"
	printf "supported_platform: darwin\n"
	printf "+ brew install --cask docker\n"
	exit 0
fi

if [[ "${MANTLE_IS_WSL:-0}" == "1" ]]; then
	mantle_log_error "Install Docker Desktop from Windows, then enable WSL integration"
	exit 69
fi
if [[ "${MANTLE_OS_FAMILY:-unknown}" != "darwin" ]]; then
	mantle_log_error "Docker Desktop installation is supported by this command only on macOS"
	mantle_log_error "Use a separate Docker Engine installer on Linux"
	exit 69
fi

MANTLE_INSTALL_TOOL_NAME="docker-desktop"
declare -a MANTLE_INSTALL_PACKAGES_BREW_CASK=("docker")

mantle_install_native_package_main "${installer_arguments[@]}"
