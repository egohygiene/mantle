#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide temporary-workspace and atomic executable-installation primitives.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/filesystem.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_FILESYSTEM_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Return whether a directory exists or can be created by the current user.
# @arg $1 string Destination directory.
# @exitcode 0 The directory is writable or creatable.
# @exitcode 1 The directory is not writable or creatable.
# @exitcode 64 Usage is invalid.
mantle_install_filesystem_can_write_directory() {
	local destination_directory="${1:-}"
	local candidate_directory=""
	local parent_directory=""

	if (($# != 1)) || [[ -z "${destination_directory}" ]]; then
		return 64
	fi
	if [[ -e "${destination_directory}" ]]; then
		[[ -d "${destination_directory}" && -w "${destination_directory}" ]]
		return
	fi

	candidate_directory="${destination_directory}"
	while [[ ! -e "${candidate_directory}" ]]; do
		parent_directory="$(dirname "${candidate_directory}")" || return 1
		if [[ "${parent_directory}" == "${candidate_directory}" ]]; then
			return 1
		fi
		candidate_directory="${parent_directory}"
	done

	[[ -d "${candidate_directory}" && -w "${candidate_directory}" ]]
}

# @description Create a private Mantle installer temporary directory.
# @stdout Absolute path to the created directory.
# @exitcode 1 The directory could not be created.
# @exitcode 64 Arguments were supplied.
mantle_install_filesystem_make_temporary_directory() {
	local temporary_root="${TMPDIR:-/tmp}"

	if (($# != 0)); then
		return 64
	fi
	if [[ ! -d "${temporary_root}" || ! -w "${temporary_root}" ]]; then
		mantle_log_error "Temporary directory is unavailable: ${temporary_root}"
		return 1
	fi

	mktemp -d "${temporary_root%/}/mantle-install.XXXXXX"
}

# @description Remove a temporary directory created by Mantle's installer runtime.
# @arg $1 string Temporary directory path.
# @exitcode 1 The path is outside the active temporary root or is unsafe.
# @exitcode 64 Usage is invalid.
mantle_install_filesystem_cleanup() {
	local temporary_directory="${1:-}"
	local temporary_root="${TMPDIR:-/tmp}"
	local canonical_root=""
	local canonical_parent=""
	local temporary_name=""

	if (($# != 1)) || [[ -z "${temporary_directory}" ]]; then
		return 64
	fi
	if [[ ! -e "${temporary_directory}" ]]; then
		return 0
	fi
	if [[ ! -d "${temporary_directory}" || -L "${temporary_directory}" ]]; then
		mantle_log_error "Refusing to clean an unsafe temporary path: ${temporary_directory}"
		return 1
	fi

	canonical_root="$(builtin cd "${temporary_root}" 2>/dev/null && pwd -P)" || return 1
	canonical_parent="$(builtin cd "$(dirname "${temporary_directory}")" 2>/dev/null && pwd -P)" || return 1
	temporary_name="${temporary_directory%/}"
	temporary_name="${temporary_name##*/}"

	if [[ "${canonical_parent}" != "${canonical_root}" || "${temporary_name}" != mantle-install.* ]]; then
		mantle_log_error "Refusing to clean a non-Mantle temporary directory: ${temporary_directory}"
		return 1
	fi

	rm -rf "${temporary_directory}"
}

# @description Atomically install a regular file as a user-writable executable.
# @arg $1 string Source file path.
# @arg $2 string Destination directory.
# @arg $3 string Optional destination filename; defaults to the source filename.
# @stdout Final installed path.
# @exitcode 64 Usage or destination name is invalid.
# @exitcode 77 The destination cannot be written without privilege escalation.
mantle_install_filesystem_install_executable() {
	local source_path="${1:-}"
	local destination_directory="${2:-}"
	local destination_name="${3:-${source_path##*/}}"
	local destination_path=""
	local staging_path=""

	if (($# < 2 || $# > 3)) || [[ ! -f "${source_path}" || ! -r "${source_path}" ]] ||
		[[ -z "${destination_directory}" || ! "${destination_name}" =~ ^[A-Za-z0-9._+-]+$ ]] ||
		[[ "${destination_name}" == "." || "${destination_name}" == ".." ]]; then
		return 64
	fi

	if ! mantle_install_filesystem_can_write_directory "${destination_directory}"; then
		mantle_log_error "Install directory is not user-writable: ${destination_directory}"
		mantle_log_error "Choose a user-owned directory with --install-dir"
		return 77
	fi
	mkdir -p "${destination_directory}" || return 1
	if [[ ! -w "${destination_directory}" ]]; then
		return 77
	fi

	destination_path="${destination_directory%/}/${destination_name}"
	staging_path="$(mktemp "${destination_directory%/}/.mantle-install-${destination_name}.XXXXXX")" || return 1

	if ! install -m 0755 "${source_path}" "${staging_path}"; then
		rm -f "${staging_path}"
		return 1
	fi
	if ! mv -f "${staging_path}" "${destination_path}"; then
		rm -f "${staging_path}"
		return 1
	fi

	printf "%s\n" "${destination_path}"
}

MANTLE_INSTALL_FILESYSTEM_LIBRARY_LOADED="1"

return 0
