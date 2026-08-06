#!/usr/bin/env bash
# shellcheck shell=bash
#
# Calculate and verify SHA-256 and SHA-512 file digests portably.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/checksum.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_CHECKSUM_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_install_checksum_normalize_algorithm() {
	case "${1:-}" in
	sha256 | SHA256 | sha-256 | SHA-256) printf "sha256\n" ;;
	sha512 | SHA512 | sha-512 | SHA-512) printf "sha512\n" ;;
	*) return 1 ;;
	esac
}

# @description Calculate a SHA-256 or SHA-512 digest for a regular file.
# @arg $1 string Checksum algorithm: sha256 or sha512.
# @arg $2 string File path.
# @stdout Lowercase hexadecimal digest.
# @exitcode 64 Usage or algorithm is invalid.
# @exitcode 69 No compatible checksum utility is available.
mantle_install_checksum_calculate() {
	local requested_algorithm="${1:-}"
	local file_path="${2:-}"
	local algorithm=""
	local checksum=""

	if (($# != 2)) || [[ ! -f "${file_path}" || ! -r "${file_path}" ]]; then
		return 64
	fi
	algorithm="$(__mantle_install_checksum_normalize_algorithm "${requested_algorithm}")" || {
		mantle_log_error "Unsupported checksum algorithm: ${requested_algorithm}"
		return 64
	}

	case "${algorithm}" in
	sha256)
		if mantle_guard_has_command sha256sum; then
			checksum="$(sha256sum "${file_path}" | awk '{print $1}')" || return 1
		elif mantle_guard_has_command shasum; then
			checksum="$(shasum -a 256 "${file_path}" | awk '{print $1}')" || return 1
		elif mantle_guard_has_command openssl; then
			checksum="$(openssl dgst -sha256 "${file_path}" | awk '{print $NF}')" || return 1
		else
			mantle_log_error "No SHA-256 utility is available"
			return 69
		fi
		;;
	sha512)
		if mantle_guard_has_command sha512sum; then
			checksum="$(sha512sum "${file_path}" | awk '{print $1}')" || return 1
		elif mantle_guard_has_command shasum; then
			checksum="$(shasum -a 512 "${file_path}" | awk '{print $1}')" || return 1
		elif mantle_guard_has_command openssl; then
			checksum="$(openssl dgst -sha512 "${file_path}" | awk '{print $NF}')" || return 1
		else
			mantle_log_error "No SHA-512 utility is available"
			return 69
		fi
		;;
	esac

	printf "%s" "${checksum}" | LC_ALL=C tr "[:upper:]" "[:lower:]"
	printf "\n"
}

# @description Verify a file against an expected SHA-256 or SHA-512 digest.
# @arg $1 string Checksum algorithm: sha256 or sha512.
# @arg $2 string File path.
# @arg $3 string Expected hexadecimal digest.
# @exitcode 1 The digest does not match.
# @exitcode 64 Usage, algorithm, or expected digest is invalid.
mantle_install_checksum_verify() {
	local requested_algorithm="${1:-}"
	local file_path="${2:-}"
	local expected_checksum="${3:-}"
	local algorithm=""
	local actual_checksum=""
	local expected_length=0

	if (($# != 3)) || [[ ! -f "${file_path}" || ! -r "${file_path}" ]]; then
		return 64
	fi
	algorithm="$(__mantle_install_checksum_normalize_algorithm "${requested_algorithm}")" || {
		mantle_log_error "Unsupported checksum algorithm: ${requested_algorithm}"
		return 64
	}

	expected_checksum="$(printf "%s" "${expected_checksum}" | LC_ALL=C tr -d "[:space:]" | tr "[:upper:]" "[:lower:]")"
	case "${algorithm}" in
	sha256) expected_length=64 ;;
	sha512) expected_length=128 ;;
	esac
	if [[ ! "${expected_checksum}" =~ ^[0-9a-f]+$ ]] || ((${#expected_checksum} != expected_length)); then
		mantle_log_error "Invalid ${algorithm} checksum"
		return 64
	fi

	actual_checksum="$(mantle_install_checksum_calculate "${algorithm}" "${file_path}")" || return $?
	if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
		mantle_log_error "Checksum mismatch (${algorithm}) for ${file_path}"
		mantle_log_error "Expected: ${expected_checksum}"
		mantle_log_error "Actual:   ${actual_checksum}"
		return 1
	fi

	mantle_log_info "Verified ${algorithm} checksum for ${file_path##*/}"
}

MANTLE_INSTALL_CHECKSUM_LIBRARY_LOADED="1"

return 0
