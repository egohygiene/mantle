#!/usr/bin/env bash
# shellcheck shell=bash
#
# Download remote artifacts with retries and atomic destination replacement.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/download.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_DOWNLOAD_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Download an HTTPS resource to a local file using curl or wget.
# @arg $1 string HTTPS URL.
# @arg $2 string Destination file path.
# @arg $@ string Optional HTTP header values after the destination path.
# @exitcode 64 Usage or URL policy is invalid.
# @exitcode 69 Neither curl nor wget is available.
mantle_install_download_file() {
	local download_url="${1:-}"
	local destination_path="${2:-}"
	local destination_directory=""
	local temporary_path=""
	local header_value=""
	local download_status=0
	local -a request_headers=()
	local -a curl_arguments=(
		--fail
		--silent
		--show-error
		--location
		--retry 3
		--retry-delay 1
		--connect-timeout 15
	)
	local -a wget_arguments=(
		--quiet
		--tries=3
		--timeout=15
	)

	if (($# < 2)) || [[ -z "${download_url}" || -z "${destination_path}" ]]; then
		return 64
	fi
	shift 2
	request_headers=("$@")

	case "${download_url}" in
	https://*) ;;
	http://*)
		case "${MANTLE_INSTALL_ALLOW_INSECURE_DOWNLOADS:-0}" in
		1 | true | yes | on) ;;
		*)
			mantle_log_error "Refusing insecure download URL: ${download_url}"
			return 64
			;;
		esac
		;;
	*)
		mantle_log_error "Unsupported download URL: ${download_url}"
		return 64
		;;
	esac

	for header_value in "${request_headers[@]}"; do
		if [[ -z "${header_value}" || "${header_value}" == *$'\n'* || "${header_value}" == *$'\r'* ]]; then
			mantle_log_error "Invalid HTTP request header"
			return 64
		fi
	done

	if [[ -d "${destination_path}" ]]; then
		mantle_log_error "Download destination is a directory: ${destination_path}"
		return 64
	fi

	destination_directory="$(dirname "${destination_path}")" || return 1
	mkdir -p "${destination_directory}" || return 1
	temporary_path="$(mktemp "${destination_directory%/}/.mantle-download.XXXXXX")" || return 1

	if mantle_guard_has_command curl; then
		if [[ "${download_url}" == https://* ]]; then
			curl_arguments+=(--proto "=https")
		fi
		for header_value in "${request_headers[@]}"; do
			curl_arguments+=(--header "${header_value}")
		done
		curl "${curl_arguments[@]}" --output "${temporary_path}" "${download_url}" || download_status=$?
	elif mantle_guard_has_command wget; then
		for header_value in "${request_headers[@]}"; do
			wget_arguments+=(--header="${header_value}")
		done
		wget "${wget_arguments[@]}" --output-document="${temporary_path}" "${download_url}" || download_status=$?
	else
		mantle_log_error "Missing download dependency: curl or wget is required"
		download_status=69
	fi

	if ((download_status != 0)); then
		rm -f "${temporary_path}"
		return "${download_status}"
	fi

	if ! mv -f "${temporary_path}" "${destination_path}"; then
		rm -f "${temporary_path}"
		return 1
	fi
}

MANTLE_INSTALL_DOWNLOAD_LIBRARY_LOADED="1"

return 0
