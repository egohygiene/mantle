#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide date formatting and GNU-date calendar arithmetic for Bash callers.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/date.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_DATE_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_date_gnu_command() {
	if command -v gdate >/dev/null 2>&1; then
		printf "%s\n" "gdate"
	elif date --version >/dev/null 2>&1; then
		printf "%s\n" "date"
	else
		return 69
	fi
}

__mantle_date_validate_epoch() {
	[[ "${1:-}" =~ ^-?[0-9]+$ ]]
}

__mantle_date_validate_amount() {
	[[ "${1:-}" =~ ^[0-9]+$ ]]
}

__mantle_date_adjust() {
	local timestamp="${1:-}"
	local amount="${2:-}"
	local unit="${3:-}"
	local direction="${4:-add}"
	local date_command=""
	local base_datetime=""
	local expression=""

	if ! __mantle_date_validate_epoch "${timestamp}" ||
		! __mantle_date_validate_amount "${amount}"; then
		return 64
	fi

	case "${unit}" in
	second | minute | hour | day | week | month | year) ;;
	*) return 64 ;;
	esac

	date_command="$(__mantle_date_gnu_command)" || {
		printf "[mantle:error] calendar arithmetic requires GNU date or gdate\n" >&2
		return 69
	}
	base_datetime="$("${date_command}" --date "@${timestamp}" "+%Y-%m-%d %H:%M:%S %z")" ||
		return $?

	case "${direction}" in
	add) expression="${base_datetime} +${amount} ${unit}" ;;
	subtract) expression="${base_datetime} -${amount} ${unit}" ;;
	*) return 64 ;;
	esac

	"${date_command}" --date "${expression}" "+%s"
}

# @description Print the current Unix epoch timestamp.
mantle_date_now() {
	date -u "+%s"
}

# @description Convert a GNU-date-compatible value to Unix epoch seconds.
mantle_date_to_epoch() {
	local date_value="${1:-}"
	local date_command=""

	if (($# != 1)) || [[ -z "${date_value}" ]]; then
		return 64
	fi

	date_command="$(__mantle_date_gnu_command)" || {
		printf "[mantle:error] date parsing requires GNU date or gdate\n" >&2
		return 69
	}

	"${date_command}" --date "${date_value}" "+%s"
}

# @description Format Unix epoch seconds in local time.
# @arg $1 integer Unix epoch seconds.
# @arg $2 string Optional strftime format.
mantle_date_format() {
	local timestamp="${1:-}"
	local output_format="${2:-%Y-%m-%d %H:%M:%S}"

	if (($# < 1 || $# > 2)) || ! __mantle_date_validate_epoch "${timestamp}"; then
		return 64
	fi

	if date --version >/dev/null 2>&1; then
		date --date "@${timestamp}" "+${output_format}"
	else
		date -r "${timestamp}" "+${output_format}"
	fi
}

# @description Add days to Unix epoch seconds.
mantle_date_add_days() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "day" "add"
}

# @description Add weeks to Unix epoch seconds.
mantle_date_add_weeks() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "week" "add"
}

# @description Add months to Unix epoch seconds.
mantle_date_add_months() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "month" "add"
}

# @description Add years to Unix epoch seconds.
mantle_date_add_years() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "year" "add"
}

# @description Subtract days from Unix epoch seconds.
mantle_date_subtract_days() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "day" "subtract"
}

# @description Subtract weeks from Unix epoch seconds.
mantle_date_subtract_weeks() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "week" "subtract"
}

# @description Subtract months from Unix epoch seconds.
mantle_date_subtract_months() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "month" "subtract"
}

# @description Subtract years from Unix epoch seconds.
mantle_date_subtract_years() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "year" "subtract"
}

# @description Subtract hours from Unix epoch seconds.
mantle_date_subtract_hours() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "hour" "subtract"
}

# @description Subtract minutes from Unix epoch seconds.
mantle_date_subtract_minutes() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "minute" "subtract"
}

# @description Subtract seconds from Unix epoch seconds.
mantle_date_subtract_seconds() {
	(($# >= 1 && $# <= 2)) || return 64
	__mantle_date_adjust "$1" "${2:-1}" "second" "subtract"
}

MANTLE_DATE_LIBRARY_LOADED="1"

return 0
