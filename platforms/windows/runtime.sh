#!/usr/bin/env bash
# shellcheck shell=bash
# Minimal MSYS2/Git Bash adapter. Native PowerShell is outside this runtime.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] platforms/windows/runtime.sh must be sourced\n" >&2
	exit 64
fi
if [[ "${MANTLE_PLATFORM_WINDOWS_LOADED:-0}" == "1" ]]; then return 0; fi

MANTLE_PLATFORM_RUNTIME="windows"
MANTLE_PLATFORM_WINDOWS_LOADED="1"
export MANTLE_PLATFORM_RUNTIME
return 0
