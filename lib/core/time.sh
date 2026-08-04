#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide portable timestamp helpers shared by Mantle runtimes.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/core/time.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_TIME_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Print Unix epoch seconds in UTC.
mantle_time_epoch() {
	date -u "+%s"
}

# @description Print Unix epoch milliseconds in UTC.
mantle_time_epoch_milliseconds() {
	local seconds=""
	local fractional=""
	local milliseconds=""
	local date_value=""

	if [[ -n "${EPOCHREALTIME:-}" ]]; then
		seconds="${EPOCHREALTIME%.*}"
		fractional="${EPOCHREALTIME#*.}"
		fractional="${fractional%%[^0-9]*}000"
		milliseconds="${fractional:0:3}"
		printf "%s%03d\n" "${seconds}" "$((10#${milliseconds}))"
		return 0
	fi

	date_value="$(date "+%s%3N" 2>/dev/null)" || date_value=""
	if [[ "${date_value}" =~ ^[0-9]{13,}$ ]]; then
		printf "%s\n" "${date_value}"
		return 0
	fi

	if command -v python3 >/dev/null 2>&1; then
		python3 - <<'PY'
import time

print(time.time_ns() // 1_000_000)
PY
		return $?
	fi

	if command -v perl >/dev/null 2>&1; then
		perl -MTime::HiRes=time -e 'printf "%d\n", int(time() * 1000)'
		return $?
	fi

	seconds="$(mantle_time_epoch)" || return $?
	printf "%s000\n" "${seconds}"
}

# @description Print a local timestamp as YYYY-MM-DD HH:MM:SS.
mantle_time_timestamp() {
	date "+%Y-%m-%d %H:%M:%S"
}

# @description Print a UTC timestamp as YYYY-MM-DD HH:MM:SS.
mantle_time_utc_timestamp() {
	TZ=UTC date "+%Y-%m-%d %H:%M:%S"
}

# @description Print an RFC 3339-compatible UTC timestamp.
mantle_time_iso8601() {
	TZ=UTC date "+%Y-%m-%dT%H:%M:%SZ"
}

MANTLE_TIME_LIBRARY_LOADED="1"

return 0
