#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide a small jq-backed JSON extraction helper.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/json.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_JSON_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Print the selected occurrence of a key found recursively in JSON.
# @arg $1 string Object key.
# @arg $2 integer Optional one-based occurrence, default 1.
# @stdin Valid JSON.
# @exitcode 1 The key occurrence was not found.
# @exitcode 64 Usage is invalid.
# @exitcode 127 jq is unavailable.
mantle_json_get_value() {
	local key_name="${1:-}"
	local occurrence="${2:-1}"
	local zero_based_index=0

	if (($# < 1 || $# > 2)) || [[ -z "${key_name}" ]] ||
		[[ ! "${occurrence}" =~ ^[1-9][0-9]*$ ]]; then
		return 64
	fi
	command -v jq >/dev/null 2>&1 || return 127

	zero_based_index=$((occurrence - 1))
	jq --exit-status --raw-output \
		--arg key "${key_name}" \
		--argjson index "${zero_based_index}" \
		'[.. | objects | select(has($key)) | .[$key]][$index]'
}

MANTLE_JSON_LIBRARY_LOADED="1"

return 0
