#!/usr/bin/env bash
# shellcheck shell=bash

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] platforms/linux/runtime.sh must be sourced\n" >&2
	exit 64
fi
if [[ "${MANTLE_PLATFORM_LINUX_LOADED:-0}" == "1" ]]; then return 0; fi
if [[ -z "${MANTLE_ROOT:-}" || ! -d "${MANTLE_ROOT}" ]]; then
	printf "[mantle:error] linux runtime requires a valid MANTLE_ROOT\n" >&2
	return 1
fi

if [[ -d "/snap/bin" ]]; then
	case ":${PATH:-}:" in *":/snap/bin:"*) ;; *)
		PATH="${PATH:+${PATH}:}/snap/bin"
		export PATH
		;;
	esac
fi
if [[ -d "/var/lib/snapd/desktop" ]]; then
	case ":${XDG_DATA_DIRS:-}:" in *":/var/lib/snapd/desktop:"*) ;; *)
		XDG_DATA_DIRS="${XDG_DATA_DIRS:+${XDG_DATA_DIRS}:}/var/lib/snapd/desktop"
		export XDG_DATA_DIRS
		;;
	esac
fi
if [[ -r "${MANTLE_ROOT}/platforms/linux/aliases.sh" ]]; then
	# shellcheck disable=SC1091
	source "${MANTLE_ROOT}/platforms/linux/aliases.sh" || return 1
fi

MANTLE_PLATFORM_RUNTIME="linux"
MANTLE_PLATFORM_LINUX_LOADED="1"
export MANTLE_PLATFORM_RUNTIME
return 0
