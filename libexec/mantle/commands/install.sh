#!/usr/bin/env bash
# shellcheck shell=bash
# Discover and dispatch Mantle's private installer implementations.

set -o errexit
set -o nounset
set -o pipefail

# @description Print mantle install usage.
mantle_install_command_usage() {
	printf "%s\n" \
		"Usage:" \
		"  mantle install TOOL [INSTALLER_OPTIONS]" \
		"  mantle install --list" \
		"  mantle install --help" \
		"" \
		"Examples:" \
		"  mantle install eza" \
		"  mantle install shfmt --version 3.12.0" \
		"  mantle install talisman --dry-run" \
		"" \
		"Installer options are forwarded unchanged to the selected tool."
}

# @description List every available Mantle installer in deterministic order.
# @stdout One installer name per line.
mantle_install_command_list() {
	local installer_path=""
	local installer_filename=""

	for installer_path in "${MANTLE_ROOT}/libexec/mantle/installers"/*.sh; do
		[[ -f "${installer_path}" && -x "${installer_path}" ]] || continue
		installer_filename="${installer_path##*/}"
		printf "%s\n" "${installer_filename%.sh}"
	done
}

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

mantle_installers_directory="${MANTLE_ROOT}/libexec/mantle/installers"
if [[ ! -d "${mantle_installers_directory}" ]]; then
	printf "[mantle:error] missing installer directory: %s\n" "${mantle_installers_directory}" >&2
	exit 70
fi

if (($# == 0)); then
	mantle_install_command_usage
	exit 0
fi

case "$1" in
--summary)
	printf "Install a supported tool through Mantle.\n"
	exit 0
	;;
--help | -h)
	mantle_install_command_usage
	exit 0
	;;
--list)
	if (($# != 1)); then
		printf "[mantle:error] --list does not accept additional arguments\n" >&2
		exit 64
	fi
	mantle_install_command_list
	exit 0
	;;
--)
	shift
	if (($# == 0)); then
		printf "[mantle:error] missing installer name after --\n" >&2
		exit 64
	fi
	;;
-*)
	printf "[mantle:error] unknown install option: %s\n" "$1" >&2
	mantle_install_command_usage >&2
	exit 64
	;;
esac

mantle_installer_name="$1"
shift

if [[ ! "${mantle_installer_name}" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
	printf "[mantle:error] invalid installer name: %s\n" "${mantle_installer_name}" >&2
	exit 64
fi

mantle_installer_path="${mantle_installers_directory}/${mantle_installer_name}.sh"
if [[ ! -f "${mantle_installer_path}" ]]; then
	printf "[mantle:error] unknown installer: %s\n" "${mantle_installer_name}" >&2
	printf "Run 'mantle install --list' to list available installers.\n" >&2
	exit 64
fi
if [[ ! -x "${mantle_installer_path}" ]]; then
	printf "[mantle:error] installer is not executable: %s\n" "${mantle_installer_path}" >&2
	exit 70
fi

MANTLE_INSTALLER_NAME="${mantle_installer_name}"
export MANTLE_INSTALLER_NAME
exec "${mantle_installer_path}" "$@"
