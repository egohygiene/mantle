#!/usr/bin/env bash
# shellcheck shell=bash
# Install reconquest/shdoc from a selected Git ref.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

shdoc_repository="${SHDOC_REPOSITORY:-https://github.com/reconquest/shdoc.git}"
shdoc_ref="${SHDOC_REF:-master}"
shdoc_install_directory="${SHDOC_INSTALL_DIRECTORY:-${XDG_BIN_HOME:-${HOME}/.local/bin}}"
dry_run="0"

# @description Print mantle install shdoc usage.
mantle_install_shdoc_usage() {
	printf "Usage: mantle install shdoc [--repository HTTPS_URL] [--ref REF] [--install-dir DIRECTORY] [--dry-run] [--help]\n"
}

# @description Print a shell-escaped command.
# @arg $@ string Command and arguments.
mantle_install_shdoc_print_command() {
	local argument=""

	printf "+"
	for argument in "$@"; do printf " %q" "${argument}"; done
	printf "\n"
}

while (($# > 0)); do
	case "$1" in
	--repository)
		if (($# < 2)) || [[ "${2:-}" != https://* ]]; then
			mantle_install_shdoc_usage >&2
			exit 64
		fi
		shdoc_repository="$2"
		shift 2
		;;
	--ref)
		if (($# < 2)) || [[ -z "${2:-}" ]]; then
			mantle_install_shdoc_usage >&2
			exit 64
		fi
		shdoc_ref="$2"
		shift 2
		;;
	--install-dir)
		if (($# < 2)) || [[ -z "${2:-}" ]]; then
			mantle_install_shdoc_usage >&2
			exit 64
		fi
		shdoc_install_directory="$2"
		shift 2
		;;
	--dry-run)
		dry_run="1"
		shift
		;;
	--help | -h)
		mantle_install_shdoc_usage
		exit 0
		;;
	*)
		mantle_log_error "Unknown argument: $1"
		mantle_install_shdoc_usage >&2
		exit 64
		;;
	esac
done

if ! mantle_guard_has_command git; then
	mantle_log_error "Installing shdoc requires git"
	exit 69
fi

if [[ "${dry_run}" == "1" ]]; then
	printf "tool: shdoc\n"
	printf "repository: %s\n" "${shdoc_repository}"
	printf "ref: %s\n" "${shdoc_ref}"
	printf "install_dir: %s\n" "${shdoc_install_directory}"
	mantle_install_shdoc_print_command git clone --filter=blob:none --no-checkout "${shdoc_repository}" TEMPORARY_DIRECTORY
	mantle_install_shdoc_print_command git -C TEMPORARY_DIRECTORY fetch --depth 1 origin "${shdoc_ref}"
	exit 0
fi

shdoc_temporary_directory="$(mantle_install_filesystem_make_temporary_directory)"
trap 'mantle_install_filesystem_cleanup "${shdoc_temporary_directory:-}" >/dev/null 2>&1 || true' EXIT
git clone --filter=blob:none --no-checkout "${shdoc_repository}" "${shdoc_temporary_directory}/shdoc"
git -C "${shdoc_temporary_directory}/shdoc" fetch --depth 1 origin "${shdoc_ref}"
git -C "${shdoc_temporary_directory}/shdoc" checkout --detach FETCH_HEAD

shdoc_source="${shdoc_temporary_directory}/shdoc/shdoc"
if [[ ! -f "${shdoc_source}" ]]; then
	mantle_log_error "The selected shdoc ref does not contain the shdoc executable"
	exit 1
fi
mantle_install_filesystem_install_executable "${shdoc_source}" "${shdoc_install_directory}" "shdoc" >/dev/null
mantle_log_success "Installed shdoc to ${shdoc_install_directory}/shdoc"
