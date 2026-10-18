# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Interactive helpers that may mutate operating-system state or request sudo.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/aliases-system.sh is internal and must be sourced\n" >&2
	exit 64
fi
if [[ "${MANTLE_INTERACTIVE:-0}" != "1" ]]; then return 0; fi

# @description Update supported Linux system package managers.
mantle_system_update() {
	local package_manager_found=0
	if [[ "${MANTLE_PLATFORM_RUNTIME:-}" == "darwin" ]] && command -v brew >/dev/null 2>&1; then
		package_manager_found=1
		command brew update && command brew upgrade || return $?
	fi
	if command -v apt-get >/dev/null 2>&1; then
		package_manager_found=1
		command sudo apt-get update &&
			command sudo apt-get --yes upgrade &&
			command sudo apt-get --yes autoremove || return $?
	fi
	if command -v snap >/dev/null 2>&1; then
		package_manager_found=1
		command sudo snap refresh || return $?
	fi
	if command -v aptitude >/dev/null 2>&1; then
		package_manager_found=1
		command sudo aptitude --yes safe-upgrade || return $?
	fi
	if ((package_manager_found == 0)); then
		printf "[mantle:error] no supported system package manager is available\n" >&2
		return 69
	fi
}

alias system-update="mantle_system_update"

if [[ "${MANTLE_PLATFORM_RUNTIME:-}" == "darwin" && -r "${MANTLE_ROOT}/platforms/darwin/aliases.sh" ]]; then
	# shellcheck disable=SC1091
	source "${MANTLE_ROOT}/platforms/darwin/aliases.sh" || return 1
fi

return 0
