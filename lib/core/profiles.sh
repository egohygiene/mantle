#!/bin/sh
# shellcheck shell=sh
# Shared profile policy for Bash, Zsh, and POSIX callers. Fish uses profiles.awk.

# @description Check whether the active profile includes one stable capability.
# @arg $1 string Capability name.
# @exitcode 0 The capability is active.
# @exitcode 1 The capability is inactive.
# @exitcode 64 The argument is invalid.
mantle_profile_has() {
	if [ "$#" -ne 1 ]; then
		return 64
	fi
	case "$1" in
	core | interactive | tooling | workstation | container | ci) ;;
	*) return 64 ;;
	esac
	case ":${MANTLE_PROFILE_CAPABILITIES:-}:" in
	*":$1:"*) return 0 ;;
	*) return 1 ;;
	esac
}

# @description Validate the trusted manifest and select one immutable shell profile.
# @arg $1 string Optional profile name, defaulting to MANTLE_PROFILE or workstation.
# @exitcode 0 The active profile and capabilities were exported.
# @exitcode 64 The profile or manifest is invalid.
# @exitcode 69 The required Awk interpreter is unavailable.
# @exitcode 78 A successfully initialized shell requested a different profile.
mantle_profile_select() {
	if [ "$#" -gt 1 ]; then
		return 64
	fi
	__mantle_profile_requested="${1:-${MANTLE_PROFILE:-workstation}}"
	case "${__mantle_profile_requested}" in
	core | interactive | workstation | container | ci | full) ;;
	*)
		printf "[mantle:error] unknown Mantle profile; choose core, interactive, workstation, container, ci, or full\n" >&2
		unset __mantle_profile_requested
		return 64
		;;
	esac
	if [ "${MANTLE_INITIALIZATION_STATE:-}" = "initialized" ] &&
		[ "${MANTLE_ACTIVE_PROFILE:-}" != "${__mantle_profile_requested}" ]; then
		printf "[mantle:error] the active Mantle profile cannot change; start a new shell\n" >&2
		unset __mantle_profile_requested
		return 78
	fi
	if [ ! -r "${MANTLE_ROOT:-}/config/profiles.tsv" ] ||
		[ ! -r "${MANTLE_ROOT:-}/lib/core/profiles.awk" ]; then
		printf "[mantle:error] the Mantle profile manifest or resolver is unavailable\n" >&2
		unset __mantle_profile_requested
		return 64
	fi
	if ! command -v awk >/dev/null 2>&1; then
		printf "[mantle:error] profile selection requires awk\n" >&2
		unset __mantle_profile_requested
		return 69
	fi
	if __mantle_profile_capabilities="$(awk -v "selected=${__mantle_profile_requested}" \
		-f "${MANTLE_ROOT}/lib/core/profiles.awk" "${MANTLE_ROOT}/config/profiles.tsv")"; then
		MANTLE_PROFILE="${__mantle_profile_requested}"
		MANTLE_ACTIVE_PROFILE="${__mantle_profile_requested}"
		MANTLE_PROFILE_CAPABILITIES="${__mantle_profile_capabilities}"
		export MANTLE_PROFILE MANTLE_ACTIVE_PROFILE MANTLE_PROFILE_CAPABILITIES
		unset __mantle_profile_requested __mantle_profile_capabilities
		return 0
	fi
	printf "%s\n" "${__mantle_profile_capabilities}" >&2
	unset __mantle_profile_requested __mantle_profile_capabilities
	return 64
}
