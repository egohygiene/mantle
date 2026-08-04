#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide focused process, network, identity, and UUID helpers for Bash.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/misc.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_MISC_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Return whether standard output is attached to a terminal.
mantle_misc_is_terminal() {
	[[ -t 1 ]]
}

# @description Probe an HTTPS endpoint without printing a response body.
# @arg $1 string Optional URL, default MANTLE_CONNECTIVITY_CHECK_URL or example.com.
# @arg $2 integer Optional timeout seconds, default 10.
mantle_misc_has_internet_connection() {
	local check_url="${1:-${MANTLE_CONNECTIVITY_CHECK_URL:-https://example.com/}}"
	local timeout_seconds="${2:-10}"

	if (($# > 2)) || [[ "${check_url}" != https://* ]] ||
		[[ ! "${timeout_seconds}" =~ ^[1-9][0-9]*$ ]]; then
		return 64
	fi
	command -v curl >/dev/null 2>&1 || return 127

	curl \
		--fail \
		--head \
		--location \
		--max-time "${timeout_seconds}" \
		--output /dev/null \
		--silent \
		--show-error \
		"${check_url}"
}

# @description Print process identifiers matching an exact process name.
mantle_misc_process_ids() {
	if (($# != 1)) || [[ -z "${1:-}" || "$1" == -* ]]; then
		return 64
	fi
	command -v pgrep >/dev/null 2>&1 || return 127

	pgrep -x "$1"
}

# @description Print the numeric user identifier for an account name.
mantle_misc_user_id() {
	if (($# != 1)) || [[ -z "${1:-}" ]]; then
		return 64
	fi

	id -u "$1" 2>/dev/null
}

# @description Print a cryptographically generated version-4 UUID when supported.
mantle_misc_generate_uuid() {
	if (($# != 0)); then
		return 64
	fi

	if command -v uuidgen >/dev/null 2>&1; then
		uuidgen | LC_ALL=C tr "[:upper:]" "[:lower:]"
	elif [[ -r "/proc/sys/kernel/random/uuid" ]]; then
		LC_ALL=C tr "[:upper:]" "[:lower:]" <"/proc/sys/kernel/random/uuid"
	elif command -v python3 >/dev/null 2>&1; then
		python3 - <<'PY'
import uuid

print(uuid.uuid4())
PY
	else
		return 69
	fi
}

MANTLE_MISC_LIBRARY_LOADED="1"

return 0
