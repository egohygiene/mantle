#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide terminal-aware formatting helpers for Bash callers.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/format.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_FORMAT_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_format_nonnegative_integer() {
	[[ "${1:-}" =~ ^[0-9]+$ ]]
}

__mantle_format_repeat() {
	local symbol="${1:- }"
	local count="${2:-0}"
	local output=""
	local index=0

	symbol="${symbol:0:1}"
	for ((index = 0; index < count; index++)); do
		output+="${symbol}"
	done
	printf "%s" "${output}"
}

# @description Enable Bash's built-in terminal-size refresh behavior.
mantle_format_initialize_window_size() {
	if (($# != 0)); then
		return 64
	fi
	shopt -s checkwinsize
	(:)
}

# @description Print the current terminal width or a safe fallback.
mantle_format_terminal_width() {
	local terminal_width="${COLUMNS:-}"

	if ! __mantle_format_nonnegative_integer "${terminal_width}" ||
		((terminal_width == 0)); then
		if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
			terminal_width="$(tput cols 2>/dev/null)" || terminal_width="80"
		else
			terminal_width="80"
		fi
	fi

	printf "%s\n" "${terminal_width}"
}

# @description Format nonnegative seconds as a concise duration.
mantle_format_seconds() {
	local total_seconds="${1:-}"
	local days=0
	local hours=0
	local minutes=0
	local seconds=0
	local output=""

	if (($# != 1)) || ! __mantle_format_nonnegative_integer "${total_seconds}"; then
		return 64
	fi

	days=$((total_seconds / 86400))
	hours=$((total_seconds / 3600 % 24))
	minutes=$((total_seconds / 60 % 60))
	seconds=$((total_seconds % 60))

	((days > 0)) && output+="${days}d "
	((hours > 0)) && output+="${hours}h "
	((minutes > 0)) && output+="${minutes}m "
	output+="${seconds}s"
	printf "%s\n" "${output}"
}

# @description Format a nonnegative byte count using IEC binary units.
mantle_format_bytes() {
	local byte_count="${1:-}"

	if (($# != 1)) || ! __mantle_format_nonnegative_integer "${byte_count}"; then
		return 64
	fi

	awk -v bytes="${byte_count}" 'BEGIN {
		split("B KiB MiB GiB TiB PiB EiB", units, " ")
		unit = 1
		while (bytes >= 1024 && unit < 7) {
			bytes /= 1024
			unit++
		}
		if (unit == 1) {
			printf "%.0f %s\n", bytes, units[unit]
		} else {
			printf "%.2f %s\n", bytes, units[unit]
		}
	}'
}

# @description Remove ANSI control-sequence introducer escape sequences.
mantle_format_strip_ansi() {
	if (($# != 1)); then
		return 64
	fi

	printf "%s" "$1" | LC_ALL=C sed $'s/\033\\[[0-9;?]*[ -\\/]*[@-~]//g'
	printf "\n"
}

# @description Center text within the current terminal width.
mantle_format_center_text() {
	local input_text="${1:-}"
	local fill_symbol="${2:- }"
	local plain_text=""
	local terminal_width=0
	local left_width=0
	local right_width=0

	if (($# < 1 || $# > 2)) || [[ -z "${fill_symbol}" ]]; then
		return 64
	fi

	plain_text="$(mantle_format_strip_ansi "${input_text}")" || return $?
	terminal_width="$(mantle_format_terminal_width)" || return $?
	if ((${#plain_text} >= terminal_width)); then
		printf "%s\n" "${input_text}"
		return 0
	fi

	left_width=$(((terminal_width - ${#plain_text}) / 2))
	right_width=$((terminal_width - ${#plain_text} - left_width))
	__mantle_format_repeat "${fill_symbol}" "${left_width}"
	printf "%s" "${input_text}"
	__mantle_format_repeat "${fill_symbol}" "${right_width}"
	printf "\n"
}

# @description Print a label and bracketed status separated by dot padding.
mantle_format_report() {
	local label="${1:-}"
	local status="${2:-}"
	local terminal_width=0
	local suffix=""
	local padding_width=1

	if (($# != 2)); then
		return 64
	fi

	terminal_width="$(mantle_format_terminal_width)" || return $?
	suffix="[ ${status} ]"
	padding_width=$((terminal_width - ${#label} - ${#suffix} - 2))
	((padding_width < 1)) && padding_width=1
	printf "%s " "${label}"
	__mantle_format_repeat "." "${padding_width}"
	printf " %s\n" "${suffix}"
}

# @description Trim one or two text segments to the current terminal width.
mantle_format_trim_to_terminal() {
	local first_text="${1:-}"
	local second_text="${2:-}"
	local terminal_width=0
	local first_limit=0
	local second_limit=0

	if (($# < 1 || $# > 2)); then
		return 64
	fi

	terminal_width="$(mantle_format_terminal_width)" || return $?
	if (($# == 1)); then
		if ((${#first_text} <= terminal_width)); then
			printf "%s\n" "${first_text}"
		elif ((terminal_width > 2)); then
			printf "%s..\n" "${first_text:0:terminal_width-2}"
		fi
		return 0
	fi

	first_limit=$((terminal_width * 45 / 100))
	second_limit=$((terminal_width - first_limit - 1))
	((${#first_text} > first_limit && first_limit > 2)) &&
		first_text="${first_text:0:first_limit-2}.."
	((${#second_text} > second_limit && second_limit > 2)) &&
		second_text="${second_text:0:second_limit-2}.."
	printf "%s %s\n" "${first_text}" "${second_text}"
}

MANTLE_FORMAT_LIBRARY_LOADED="1"

return 0
