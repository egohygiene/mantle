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
		"  mantle install --assurance [TOOL]" \
		"  mantle install --help" \
		"" \
		"Examples:" \
		"  mantle install eza" \
		"  mantle install --assurance eza" \
		"  mantle install shfmt --version 3.12.0" \
		"  mantle install talisman --dry-run" \
		"" \
		"Installer options are forwarded unchanged to the selected tool."
}

# @description Print the installer assurance matrix, optionally for one installer.
# @arg $1 string Optional installer name.
mantle_install_command_assurance() {
	local requested_installer="${1:-}"
	local registry="${MANTLE_ROOT}/config/installers.lock.tsv"

	if [[ -n "${requested_installer}" && ! "${requested_installer}" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
		printf "[mantle:error] invalid installer name: %s\n" "${requested_installer}" >&2
		return 64
	fi
	if [[ ! -r "${registry}" ]]; then
		printf "[mantle:error] missing installer assurance registry: %s\n" "${registry}" >&2
		return 70
	fi

	awk -F '\t' -v requested="${requested_installer}" '
		BEGIN {
			printf "%-18s %-18s %-16s %-18s %s\n", "INSTALLER", "COMPONENT", "RESOLVER", "VERIFICATION", "LOCK"
		}
		/^#/ || $1 == "installer" { next }
		requested == "" || $1 == requested {
			printf "%-18s %-18s %-16s %-18s %s\n", $1, $2, $3, $7, $6
			found = 1
		}
		END { if (requested != "" && !found) exit 1 }
	' "${registry}" || {
		printf "[mantle:error] no assurance record for installer: %s\n" "${requested_installer}" >&2
		return 64
	}
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
--assurance)
	if (($# > 2)); then
		printf "[mantle:error] --assurance accepts at most one installer name\n" >&2
		exit 64
	fi
	mantle_install_command_assurance "${2:-}"
	exit $?
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
