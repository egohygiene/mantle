#!/usr/bin/env bash
# shellcheck shell=bash
#
# Detect, validate, and extract common release-archive formats.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/archive.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_ARCHIVE_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_install_archive_member_path_is_safe() {
	local member_path="${1:-}"

	member_path="${member_path//\\//}"
	case "${member_path}" in
		"" | / | /* | -*) return 1 ;;
		. | .. | ../* | */../* | */..) return 1 ;;
		[A-Za-z]:/*) return 1 ;;
	esac

	return 0
}

__mantle_install_archive_list() {
	local archive_path="${1:-}"
	local archive_format="${2:-}"

	case "${archive_format}" in
		tar) tar -tf "${archive_path}" ;;
		tar.gz) tar -tzf "${archive_path}" ;;
		tar.xz) tar -tJf "${archive_path}" ;;
		tar.bz2) tar -tjf "${archive_path}" ;;
		zip) unzip -Z1 "${archive_path}" ;;
		*) return 64 ;;
	esac
}

__mantle_install_archive_validate_contents() {
	local archive_path="${1:-}"
	local archive_format="${2:-}"
	local archive_listing=""
	local member_path=""

	archive_listing="$(__mantle_install_archive_list "${archive_path}" "${archive_format}")" || {
		mantle_log_error "Unable to inspect archive: ${archive_path}"
		return 1
	}

	while IFS= read -r member_path || [[ -n "${member_path}" ]]; do
		member_path="${member_path#./}"
		if [[ -n "${member_path}" ]] && ! __mantle_install_archive_member_path_is_safe "${member_path}"; then
			mantle_log_error "Archive contains an unsafe member path: ${member_path}"
			return 1
		fi
	done <<<"${archive_listing}"
}

# @description Detect the extraction format from an artifact filename.
# @arg $1 string Artifact path or filename.
# @stdout raw, tar, tar.gz, tar.xz, tar.bz2, or zip.
# @exitcode 64 Usage is invalid.
mantle_install_archive_format() {
	local archive_path="${1:-}"

	if (($# != 1)) || [[ -z "${archive_path}" ]]; then
		return 64
	fi

	case "${archive_path}" in
		*.tar.gz | *.tgz) printf "tar.gz\n" ;;
		*.tar.xz | *.txz) printf "tar.xz\n" ;;
		*.tar.bz2 | *.tbz2) printf "tar.bz2\n" ;;
		*.tar) printf "tar\n" ;;
		*.zip) printf "zip\n" ;;
		*) printf "raw\n" ;;
	esac
}

# @description Extract an archive, optionally limiting extraction to one exact member.
# @arg $1 string Archive or raw artifact path.
# @arg $2 string Destination directory.
# @arg $3 string Optional archive member path.
# @arg $4 string Optional explicit archive format.
# @exitcode 64 Usage or format is invalid.
# @exitcode 69 A required extraction utility is unavailable.
mantle_install_archive_extract() {
	local archive_path="${1:-}"
	local destination_directory="${2:-}"
	local member_path="${3:-}"
	local archive_format="${4:-}"
	local required_command=""

	if (($# < 2 || $# > 4)) || [[ ! -f "${archive_path}" || ! -r "${archive_path}" ]] ||
		[[ -z "${destination_directory}" || -L "${destination_directory}" ]]; then
		return 64
	fi
	if [[ -n "${member_path}" ]]; then
		if ! __mantle_install_archive_member_path_is_safe "${member_path}" ||
			[[ "${member_path}" == *"*"* || "${member_path}" == *"?"* || "${member_path}" == *"["* ]]; then
			mantle_log_error "Unsafe or ambiguous archive member path: ${member_path}"
			return 64
		fi
	fi

	if [[ -z "${archive_format}" ]]; then
		archive_format="$(mantle_install_archive_format "${archive_path}")" || return $?
	fi
	case "${archive_format}" in
		raw) required_command="cp" ;;
		tar | tar.gz | tar.xz | tar.bz2) required_command="tar" ;;
		zip) required_command="unzip" ;;
		*)
			mantle_log_error "Unsupported archive format: ${archive_format}"
			return 64
			;;
	esac
	if ! mantle_guard_has_command "${required_command}"; then
		mantle_log_error "Missing archive dependency: ${required_command}"
		return 69
	fi

	mkdir -p "${destination_directory}" || return 1
	if [[ "${archive_format}" != "raw" ]]; then
		__mantle_install_archive_validate_contents "${archive_path}" "${archive_format}" || return $?
	fi

	case "${archive_format}" in
		raw)
			if [[ -n "${member_path}" ]]; then
				mantle_log_error "Raw artifacts do not support archive-member extraction"
				return 64
			fi
			cp "${archive_path}" "${destination_directory%/}/${archive_path##*/}"
			;;
		tar)
			if [[ -n "${member_path}" ]]; then
				tar -xf "${archive_path}" -C "${destination_directory}" "${member_path}"
			else
				tar -xf "${archive_path}" -C "${destination_directory}"
			fi
			;;
		tar.gz)
			if [[ -n "${member_path}" ]]; then
				tar -xzf "${archive_path}" -C "${destination_directory}" "${member_path}"
			else
				tar -xzf "${archive_path}" -C "${destination_directory}"
			fi
			;;
		tar.xz)
			if [[ -n "${member_path}" ]]; then
				tar -xJf "${archive_path}" -C "${destination_directory}" "${member_path}"
			else
				tar -xJf "${archive_path}" -C "${destination_directory}"
			fi
			;;
		tar.bz2)
			if [[ -n "${member_path}" ]]; then
				tar -xjf "${archive_path}" -C "${destination_directory}" "${member_path}"
			else
				tar -xjf "${archive_path}" -C "${destination_directory}"
			fi
			;;
		zip)
			if [[ -n "${member_path}" ]]; then
				unzip -q -o "${archive_path}" "${member_path}" -d "${destination_directory}"
			else
				unzip -q -o "${archive_path}" -d "${destination_directory}"
			fi
			;;
	esac
}

MANTLE_INSTALL_ARCHIVE_LIBRARY_LOADED="1"

return 0
