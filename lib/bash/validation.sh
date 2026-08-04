#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide Bash-native validation predicates and dotted-version comparison.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/validation.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_VALIDATION_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_validation_require_one_argument() {
	(($# == 1))
}

__mantle_validation_trim_leading_zeroes() {
	local value="${1:-0}"

	while [[ "${value}" == 0* && "${#value}" -gt 1 ]]; do
		value="${value#0}"
	done
	printf "%s\n" "${value}"
}

# @description Return whether a value resembles a practical email address.
mantle_validation_email() {
	local email_pattern='^[A-Za-z0-9.!_%+~-]+@[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$'

	__mantle_validation_require_one_argument "$@" || return 64
	[[ "$1" =~ ${email_pattern} ]]
}

# @description Return whether a value is a valid dotted-decimal IPv4 address.
mantle_validation_ipv4() {
	local ip_address="${1:-}"
	local octet=""
	local IFS="."
	local -a octets=()

	__mantle_validation_require_one_argument "$@" || return 64
	[[ "${ip_address}" =~ ^[0-9]+([.][0-9]+){3}$ ]] || return 1
	read -r -a octets <<<"${ip_address}"
	((${#octets[@]} == 4)) || return 1

	for octet in "${octets[@]}"; do
		((10#${octet} <= 255)) || return 1
	done
}

# @description Return whether a value has a valid IPv6 textual form.
mantle_validation_ipv6() {
	local ip_address="${1:-}"
	local ipv6_pattern="^(([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}|([0-9A-Fa-f]{1,4}:){1,7}:|([0-9A-Fa-f]{1,4}:){1,6}:[0-9A-Fa-f]{1,4}|([0-9A-Fa-f]{1,4}:){1,5}(:[0-9A-Fa-f]{1,4}){1,2}|([0-9A-Fa-f]{1,4}:){1,4}(:[0-9A-Fa-f]{1,4}){1,3}|([0-9A-Fa-f]{1,4}:){1,3}(:[0-9A-Fa-f]{1,4}){1,4}|([0-9A-Fa-f]{1,4}:){1,2}(:[0-9A-Fa-f]{1,4}){1,5}|[0-9A-Fa-f]{1,4}:((:[0-9A-Fa-f]{1,4}){1,6})|:((:[0-9A-Fa-f]{1,4}){1,7}|:))$"

	__mantle_validation_require_one_argument "$@" || return 64
	[[ "${ip_address}" =~ ${ipv6_pattern} ]]
}

# @description Return whether a value contains alphabetic characters only.
mantle_validation_alpha() {
	__mantle_validation_require_one_argument "$@" || return 64
	[[ "$1" =~ ^[[:alpha:]]+$ ]]
}

# @description Return whether a value contains alphanumeric characters only.
mantle_validation_alphanumeric() {
	__mantle_validation_require_one_argument "$@" || return 64
	[[ "$1" =~ ^[[:alnum:]]+$ ]]
}

# @description Return whether a value contains letters, underscores, or dashes only.
mantle_validation_alpha_dash() {
	__mantle_validation_require_one_argument "$@" || return 64
	[[ "$1" =~ ^[[:alpha:]_-]+$ ]]
}

# @description Compare two dotted numeric versions.
# @exitcode 0 Versions are equal.
# @exitcode 1 The first version is greater.
# @exitcode 2 The first version is less.
# @exitcode 64 Either version is invalid.
mantle_validation_compare_versions() {
	local first_version="${1:-}"
	local second_version="${2:-}"
	local IFS="."
	local -a first_parts=()
	local -a second_parts=()
	local part_index=0
	local part_count=0
	local first_part=""
	local second_part=""

	if (($# != 2)) ||
		[[ ! "${first_version}" =~ ^[0-9]+([.][0-9]+)*$ ]] ||
		[[ ! "${second_version}" =~ ^[0-9]+([.][0-9]+)*$ ]]; then
		return 64
	fi

	read -r -a first_parts <<<"${first_version}"
	read -r -a second_parts <<<"${second_version}"
	part_count=${#first_parts[@]}
	((${#second_parts[@]} > part_count)) && part_count=${#second_parts[@]}

	for ((part_index = 0; part_index < part_count; part_index++)); do
		first_part="$(__mantle_validation_trim_leading_zeroes "${first_parts[part_index]:-0}")"
		second_part="$(__mantle_validation_trim_leading_zeroes "${second_parts[part_index]:-0}")"

		((${#first_part} > ${#second_part})) && return 1
		((${#first_part} < ${#second_part})) && return 2
		[[ "${first_part}" > "${second_part}" ]] && return 1
		[[ "${first_part}" < "${second_part}" ]] && return 2
	done

	return 0
}

MANTLE_VALIDATION_LIBRARY_LOADED="1"

return 0
