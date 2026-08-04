#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide explicit, side-effect-limited file and path helpers for Bash.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/file.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_FILE_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_file_validate_temp_prefix() {
	[[ "${1:-}" =~ ^[A-Za-z0-9._-]+$ ]]
}

# @description Create a temporary file; the caller owns cleanup.
# @arg $1 string Optional basename prefix.
mantle_file_make_temporary_file() {
	local prefix="${1:-mantle}"
	local temporary_root="${TMPDIR:-/tmp}"

	if (($# > 1)) || ! __mantle_file_validate_temp_prefix "${prefix}"; then
		return 64
	fi

	mktemp "${temporary_root%/}/${prefix}.XXXXXX"
}

# @description Create a temporary directory; the caller owns cleanup.
# @arg $1 string Optional basename prefix.
mantle_file_make_temporary_directory() {
	local prefix="${1:-mantle}"
	local temporary_root="${TMPDIR:-/tmp}"

	if (($# > 1)) || ! __mantle_file_validate_temp_prefix "${prefix}"; then
		return 64
	fi

	mktemp -d "${temporary_root%/}/${prefix}.XXXXXX"
}

# @description Print the final path component.
mantle_file_name() {
	(($# == 1)) || return 64
	printf "%s\n" "${1##*/}"
}

# @description Print a filename without its final extension.
mantle_file_basename() {
	local filename="${1:-}"

	(($# == 1)) || return 64
	filename="${filename##*/}"
	if [[ "${filename}" == .* && "${filename#*.}" != *.* ]] ||
		[[ "${filename}" != *.* || "${filename}" == *. ]]; then
		printf "%s\n" "${filename}"
	else
		printf "%s\n" "${filename%.*}"
	fi
}

# @description Print a filename's final extension without the leading dot.
mantle_file_extension() {
	local filename="${1:-}"

	(($# == 1)) || return 64
	filename="${filename##*/}"
	if [[ "${filename}" == .* && "${filename#*.}" != *.* ]] ||
		[[ "${filename}" != *.* || "${filename}" == *. ]]; then
		return 1
	fi

	printf "%s\n" "${filename##*.}"
}

# @description Print a path's directory component.
mantle_file_directory_name() {
	local path_value="${1:-}"
	local directory_value=""

	(($# == 1)) || return 64
	if [[ "${path_value}" != *[!/]* ]]; then
		printf "/\n"
		return 0
	fi

	path_value="${path_value%%"${path_value##*[!/]}"}"
	if [[ "${path_value}" != */* ]]; then
		printf ".\n"
		return 0
	fi

	directory_value="${path_value%/*}"
	directory_value="${directory_value%%"${directory_value##*[!/]}"}"
	printf "%s\n" "${directory_value:-/}"
}

# @description Resolve an existing path to an absolute physical path.
mantle_file_full_path() {
	local input_path="${1:-}"
	local directory_path=""
	local filename=""

	if (($# != 1)) || [[ ! -e "${input_path}" && ! -L "${input_path}" ]]; then
		return 1
	fi

	if [[ -d "${input_path}" ]]; then
		(
			builtin cd -- "${input_path}" && pwd -P
		)
	else
		directory_path="$(mantle_file_directory_name "${input_path}")" || return $?
		filename="${input_path##*/}"
		(
			builtin cd -- "${directory_path}" &&
				printf "%s/%s\n" "$(pwd -P)" "${filename}"
		)
	fi
}

# @description Print the MIME type of an existing regular file.
mantle_file_mime_type() {
	local input_path="${1:-}"

	if (($# != 1)) || [[ ! -f "${input_path}" ]]; then
		return 1
	fi

	if command -v file >/dev/null 2>&1; then
		file --brief --mime-type -- "${input_path}"
	elif command -v mimetype >/dev/null 2>&1; then
		mimetype --output-format "%m" -- "${input_path}"
	else
		return 127
	fi
}

# @description Return whether a regular file contains literal text.
mantle_file_contains_text() {
	local input_path="${1:-}"
	local search_text="${2:-}"

	if (($# != 2)) || [[ ! -f "${input_path}" ]]; then
		return 64
	fi

	grep -F -q -- "${search_text}" "${input_path}"
}

# @description Print the owner name of an existing path.
mantle_file_owner() {
	local input_path="${1:-}"

	if (($# != 1)) || [[ ! -e "${input_path}" && ! -L "${input_path}" ]]; then
		return 1
	fi

	stat -c "%U" -- "${input_path}" 2>/dev/null ||
		stat -f "%Su" "${input_path}" 2>/dev/null
}

# @description Return whether an existing directory contains no entries.
mantle_file_directory_is_empty() {
	local directory_path="${1:-}"
	local entry_path=""

	if (($# != 1)) || [[ ! -d "${directory_path}" ]]; then
		return 64
	fi

	for entry_path in \
		"${directory_path}"/* \
		"${directory_path}"/.[!.]* \
		"${directory_path}"/..?*; do
		if [[ -e "${entry_path}" || -L "${entry_path}" ]]; then
			return 1
		fi
	done

	return 0
}

MANTLE_FILE_LIBRARY_LOADED="1"

return 0
