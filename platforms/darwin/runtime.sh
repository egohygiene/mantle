#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] platforms/darwin/runtime.sh must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_PLATFORM_DARWIN_LOADED:-0}" == "1" ]]; then
	return 0
fi

if [[ -z "${MANTLE_ROOT:-}" || ! -d "${MANTLE_ROOT}" ]]; then
	printf "[mantle:error] darwin runtime requires a valid MANTLE_ROOT\n" >&2
	return 1
fi

__mantle_darwin_path_prepend() {
	local candidate="${1:-}"
	[[ -n "${candidate}" && "${candidate}" != *:* ]] || return 64
	case ":${PATH:-}:" in *":${candidate}:"*) return 0 ;; esac
	PATH="${candidate}${PATH:+:${PATH}}"
	export PATH
}

# Lowest-to-highest priority because every discovered path is prepended.
for __mantle_darwin_path in "/usr/local/sbin" "/usr/local/bin" "/opt/homebrew/sbin" "/opt/homebrew/bin"; do
	if [[ -d "${__mantle_darwin_path}" ]]; then
		__mantle_darwin_path_prepend "${__mantle_darwin_path}" || {
			unset -f __mantle_darwin_path_prepend
			unset __mantle_darwin_path
			return 1
		}
	fi
done

if [[ -r "${MANTLE_ROOT}/platforms/darwin/aliases.sh" ]]; then
	# shellcheck disable=SC1091
	source "${MANTLE_ROOT}/platforms/darwin/aliases.sh" || {
		unset -f __mantle_darwin_path_prepend
		unset __mantle_darwin_path
		return 1
	}
fi

MANTLE_PLATFORM_RUNTIME="darwin"
MANTLE_PLATFORM_DARWIN_LOADED="1"
export MANTLE_PLATFORM_RUNTIME

unset -f __mantle_darwin_path_prepend
unset __mantle_darwin_path
return 0
