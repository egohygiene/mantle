#!/usr/bin/env bash
# shellcheck shell=bash
#
# Mantle Shell Library — Core Utilities
#
# Foundational, side-effect-minimal helpers for Bash 3.2+.
#
# This file must be sourced. It deliberately does not enable shell options such
# as errexit, nounset, or pipefail because a library must not mutate the calling
# shell's execution policy.
#
# Public API:
#   Environment:  mantle_core_path_contains, mantle_core_path_prepend, mantle_core_path_append
#   Commands:     mantle_core_has_command, mantle_core_require_command, mantle_core_retry
#   Filesystem:   mantle_core_set_owner, mantle_core_ensure_directory,
#                 mantle_core_directory_is_empty
#   System:       mantle_core_platform, mantle_core_total_memory_bytes, mantle_core_is_root
#   Accounts:     mantle_core_user_exists, mantle_core_group_exists, mantle_core_user_in_group,
#                 mantle_core_ensure_group, mantle_core_ensure_group_membership,
#                 mantle_core_ensure_user
#
# Common return statuses:
#   0   Success or a true predicate.
#   1   False predicate or an underlying operation failure.
#   64  Invalid usage or input.
#   69  Unsupported platform or missing platform capability.
#   77  Insufficient privileges.
#   127 Required command unavailable.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/core/core.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_CORE_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# -----------------------------------------------------------------------------
# Internal diagnostics and validation
# -----------------------------------------------------------------------------

# @description Print a core-library error message.
# @arg $1 string Error message.
# @stderr The formatted error message.
__mantle_core_error() {
	printf 'core: error: %s\n' "${1:-unknown error}" >&2
}

# @description Return whether a value is a positive decimal integer.
# @arg $1 string Candidate value.
# @exitcode 0 If valid; otherwise 1.
__mantle_core_is_positive_integer() {
	case "${1-}" in
		"" | *[!0-9]* | 0 | 0*) return 1 ;;
		*) return 0 ;;
	esac
}

# @description Return whether a value is a nonnegative decimal integer.
# @arg $1 string Candidate value.
# @exitcode 0 If valid; otherwise 1.
__mantle_core_is_nonnegative_integer() {
	case "${1-}" in
		"" | *[!0-9]*) return 1 ;;
		*) return 0 ;;
	esac
}

# @description Return whether a name belongs to the portable account-name subset.
# @arg $1 string User or group name.
# @exitcode 0 If valid; otherwise 1.
__mantle_core_is_account_name() {
	case "${1-}" in
		"" | [!A-Za-z_]* | *[!A-Za-z0-9._-]*) return 1 ;;
		*) return 0 ;;
	esac
}

# @description Require root privileges for a system mutation.
# @exitcode 0 If running as root.
# @exitcode 77 Otherwise.
__mantle_core_require_root() {
	if mantle_core_is_root; then
		return 0
	fi

	__mantle_core_error "this operation requires root privileges"
	return 77
}

# -----------------------------------------------------------------------------
# Platform and command capabilities
# -----------------------------------------------------------------------------

# @description Print the normalized host platform name.
# @stdout One of linux, macos, freebsd, netbsd, openbsd, windows, cygwin, unknown.
# @exitcode 0 For a recognized platform.
# @exitcode 69 For an unrecognized platform.
mantle_core_platform() {
	local kernel_name

	if ! kernel_name=$(uname -s 2>/dev/null); then
		printf '%s\n' "unknown"
		return 69
	fi

	case "$kernel_name" in
		Linux) printf '%s\n' "linux" ;;
		Darwin) printf '%s\n' "macos" ;;
		FreeBSD) printf '%s\n' "freebsd" ;;
		NetBSD) printf '%s\n' "netbsd" ;;
		OpenBSD) printf '%s\n' "openbsd" ;;
		CYGWIN*) printf '%s\n' "cygwin" ;;
		MINGW* | MSYS*) printf '%s\n' "windows" ;;
		*)
			printf '%s\n' "unknown"
			return 69
			;;
	esac
}

# @description Return whether a command is available to the calling shell.
# @arg $1 string Command name or path.
# @exitcode 0 If available.
# @exitcode 1 If unavailable.
# @exitcode 64 If the argument is missing.
mantle_core_has_command() {
	if (($# != 1)) || [[ -z "${1-}" ]]; then
		__mantle_core_error "mantle_core_has_command expects exactly one command name"
		return 64
	fi

	command -v "$1" >/dev/null 2>&1
}

# @description Require a command and print an actionable error when unavailable.
# @arg $1 string Command name or path.
# @arg $2 string Optional installation or remediation hint.
# @exitcode 0 If available.
# @exitcode 64 If usage is invalid.
# @exitcode 127 If unavailable.
mantle_core_require_command() {
	local command_name=${1-}
	local hint=${2-}

	if (($# < 1 || $# > 2)) || [[ -z "$command_name" ]]; then
		__mantle_core_error "mantle_core_require_command expects COMMAND [HINT]"
		return 64
	fi

	if mantle_core_has_command "$command_name"; then
		return 0
	fi

	__mantle_core_error "required command not found on PATH: $command_name"
	if [[ -n "$hint" ]]; then
		printf 'core: hint: %s\n' "$hint" >&2
	fi
	return 127
}

# -----------------------------------------------------------------------------
# PATH management
# -----------------------------------------------------------------------------

# @description Return whether a directory is already an exact PATH entry.
# @arg $1 string Directory path.
# @exitcode 0 If present.
# @exitcode 1 If absent.
# @exitcode 64 If the path is empty or contains the PATH delimiter.
mantle_core_path_contains() {
	local directory=${1-}
	local path_value

	if (($# != 1)) || [[ -z "$directory" ]]; then
		__mantle_core_error "mantle_core_path_contains expects one nonempty directory"
		return 64
	fi
	case "$directory" in
		*:*)
			__mantle_core_error "PATH entries cannot contain a colon: $directory"
			return 64
			;;
		*$'\n'*)
			__mantle_core_error "PATH entries containing newlines are unsupported"
			return 64
			;;
	esac

	while [[ "$directory" != "/" && "$directory" == */ ]]; do
		directory=${directory%/}
	done

	path_value=":${PATH-}:"
	case "$path_value" in
		*":${directory}:"*) return 0 ;;
		*::*)
			[[ "$directory" == "." ]] && return 0
			;;
	esac
	return 1
}

# @description Prepend an existing directory to PATH when it is not present.
# @arg $1 string Existing directory path.
# @exitcode 0 If added or already present.
# @exitcode 64 If the argument is invalid or is not a directory.
mantle_core_path_prepend() {
	local directory=${1-}
	local path_check_status

	if (($# != 1)) || [[ -z "$directory" ]]; then
		__mantle_core_error "mantle_core_path_prepend expects one nonempty directory"
		return 64
	fi
	if [[ ! -d "$directory" ]]; then
		__mantle_core_error "PATH entry is not a directory: $directory"
		return 64
	fi

	if mantle_core_path_contains "$directory"; then
		return 0
	else
		path_check_status=$?
		if ((path_check_status != 1)); then
			return "$path_check_status"
		fi
	fi

	while [[ "$directory" != "/" && "$directory" == */ ]]; do
		directory=${directory%/}
	done

	if [[ -n "${PATH-}" ]]; then
		PATH="${directory}:${PATH}"
	else
		PATH=$directory
	fi
	export PATH
}

# @description Append an existing directory to PATH when it is not present.
# @arg $1 string Existing directory path.
# @exitcode 0 If added or already present.
# @exitcode 64 If the argument is invalid or is not a directory.
mantle_core_path_append() {
	local directory=${1-}
	local path_check_status

	if (($# != 1)) || [[ -z "$directory" ]]; then
		__mantle_core_error "mantle_core_path_append expects one nonempty directory"
		return 64
	fi
	if [[ ! -d "$directory" ]]; then
		__mantle_core_error "PATH entry is not a directory: $directory"
		return 64
	fi

	if mantle_core_path_contains "$directory"; then
		return 0
	else
		path_check_status=$?
		if ((path_check_status != 1)); then
			return "$path_check_status"
		fi
	fi

	while [[ "$directory" != "/" && "$directory" == */ ]]; do
		directory=${directory%/}
	done

	if [[ -n "${PATH-}" ]]; then
		PATH="${PATH}:${directory}"
	else
		PATH=$directory
	fi
	export PATH
}

# -----------------------------------------------------------------------------
# Command execution
# -----------------------------------------------------------------------------

# @description Retry a command until success or the maximum attempt count.
# @arg $1 integer Maximum attempts, including the initial execution.
# @arg $2 integer Nonnegative delay in whole seconds between attempts.
# @arg $3 string Command name.
# @arg $@ string Remaining command arguments.
# @exitcode 0 If the command succeeds.
# @exitcode 64 If usage is invalid.
# @example mantle_core_retry 5 2 curl --fail --silent https://example.com/health
mantle_core_retry() {
	local __core_retry_max_attempts=${1-}
	local __core_retry_delay_seconds=${2-}
	local __core_retry_attempt=1
	local __core_retry_status

	if (($# < 3)); then
		__mantle_core_error "mantle_core_retry expects ATTEMPTS DELAY COMMAND [ARG...]"
		return 64
	fi
	if ! __mantle_core_is_positive_integer "$__core_retry_max_attempts"; then
		__mantle_core_error "retry attempt count must be a positive integer"
		return 64
	fi
	if ! __mantle_core_is_nonnegative_integer "$__core_retry_delay_seconds"; then
		__mantle_core_error "retry delay must be a nonnegative integer"
		return 64
	fi

	shift 2
	while ((__core_retry_attempt <= __core_retry_max_attempts)); do
		if "$@"; then
			return 0
		else
			__core_retry_status=$?
		fi

		if ((__core_retry_attempt == __core_retry_max_attempts)); then
			return "$__core_retry_status"
		fi

		if ((__core_retry_delay_seconds > 0)); then
			if sleep "$__core_retry_delay_seconds"; then
				:
			else
				__core_retry_status=$?
				__mantle_core_error "sleep failed while waiting to retry"
				return "$__core_retry_status"
			fi
		fi
		((__core_retry_attempt += 1))
	done

	return "$__core_retry_status"
}

# -----------------------------------------------------------------------------
# Filesystem helpers
# -----------------------------------------------------------------------------

# @description Set a path's owner and group without recursive traversal.
# @arg $1 string Existing file or directory path.
# @arg $2 string Existing user name.
# @arg $3 string Optional existing group; defaults to the user's primary group.
# @exitcode 0 On success.
# @exitcode 64 For invalid input.
# @exitcode 1 If chown fails.
mantle_core_set_owner() {
	local path=${1-}
	local owner=${2-}
	local group=${3-}
	local operand_path
	local lookup_status

	if (($# < 2 || $# > 3)) || [[ -z "$path" || -z "$owner" ]]; then
		__mantle_core_error "mantle_core_set_owner expects PATH OWNER [GROUP]"
		return 64
	fi
	if [[ ! -e "$path" && ! -L "$path" ]]; then
		__mantle_core_error "cannot set ownership of a missing path: $path"
		return 64
	fi
	if ! __mantle_core_is_account_name "$owner"; then
		__mantle_core_error "invalid portable owner name: $owner"
		return 64
	fi
	if [[ -n "$group" ]] && ! __mantle_core_is_account_name "$group"; then
		__mantle_core_error "invalid portable group name: $group"
		return 64
	fi
	if ! mantle_core_user_exists "$owner"; then
		__mantle_core_error "owner does not exist: $owner"
		return 64
	fi

	if [[ -z "$group" ]]; then
		if ! group=$(id -gn "$owner" 2>/dev/null); then
			__mantle_core_error "could not determine primary group for user: $owner"
			return 1
		fi
	else
		if mantle_core_group_exists "$group"; then
			:
		else
			lookup_status=$?
			if ((lookup_status == 1)); then
				__mantle_core_error "group does not exist: $group"
				return 64
			fi
			return "$lookup_status"
		fi
	fi

	case "$path" in
		-*) operand_path="./$path" ;;
		*) operand_path=$path ;;
	esac
	if ! chown "${owner}:${group}" "$operand_path"; then
		__mantle_core_error "failed to set ownership on: $path"
		return 1
	fi
}

# @description Ensure a directory exists and optionally set its ownership.
# @arg $1 string Directory path.
# @arg $2 string Optional owner.
# @arg $3 string Optional group; requires OWNER and defaults to its primary group.
# @exitcode 0 On success.
# @exitcode 64 For invalid input.
# @exitcode 1 If creation or ownership fails.
mantle_core_ensure_directory() {
	local directory=${1-}
	local owner=${2-}
	local group=${3-}
	local operand_path

	if (($# < 1 || $# > 3)) || [[ -z "$directory" ]]; then
		__mantle_core_error "mantle_core_ensure_directory expects DIRECTORY [OWNER [GROUP]]"
		return 64
	fi
	if [[ -n "$group" && -z "$owner" ]]; then
		__mantle_core_error "GROUP cannot be supplied without OWNER"
		return 64
	fi
	if [[ -e "$directory" && ! -d "$directory" ]]; then
		__mantle_core_error "directory path exists as another file type: $directory"
		return 64
	fi

	case "$directory" in
		-*) operand_path="./$directory" ;;
		*) operand_path=$directory ;;
	esac
	if ! mkdir -p "$operand_path"; then
		__mantle_core_error "failed to create directory: $directory"
		return 1
	fi

	if [[ -n "$owner" ]]; then
		mantle_core_set_owner "$directory" "$owner" "$group"
	fi
}

# @description Return whether an existing directory contains no entries.
# @arg $1 string Existing directory path.
# @exitcode 0 If empty.
# @exitcode 1 If nonempty.
# @exitcode 64 If the argument is missing or is not a directory.
mantle_core_directory_is_empty() {
	local directory=${1-}
	local entry

	if (($# != 1)) || [[ -z "$directory" ]]; then
		__mantle_core_error "mantle_core_directory_is_empty expects one directory"
		return 64
	fi
	if [[ ! -d "$directory" ]]; then
		__mantle_core_error "not a directory: $directory"
		return 64
	fi

	for entry in \
		"$directory"/* \
		"$directory"/.[!.]* \
		"$directory"/..?*; do
		if [[ -e "$entry" || -L "$entry" ]]; then
			return 1
		fi
	done

	return 0
}

# -----------------------------------------------------------------------------
# System information
# -----------------------------------------------------------------------------

# @description Return whether the effective user ID is zero.
# @exitcode 0 If running as root.
# @exitcode 1 Otherwise.
mantle_core_is_root() {
	local effective_uid

	if ! effective_uid=$(id -u 2>/dev/null); then
		__mantle_core_error "could not determine the effective user ID"
		return 1
	fi
	[[ "$effective_uid" == "0" ]]
}

# @description Print total physical memory in bytes.
# @stdout Total memory as an integer byte count.
# @exitcode 0 On success.
# @exitcode 69 If no supported memory-information interface is available.
mantle_core_total_memory_bytes() {
	local key
	local value
	local pages
	local page_size
	local sysctl_key

	if (($# != 0)); then
		__mantle_core_error "mantle_core_total_memory_bytes does not accept arguments"
		return 64
	fi

	if [[ -r "/proc/meminfo" ]]; then
		while read -r key value _; do
			if [[ "$key" == "MemTotal:" ]] && __mantle_core_is_nonnegative_integer "$value"; then
				printf '%s\n' "$((value * 1024))"
				return 0
			fi
		done <"/proc/meminfo"
	fi

	if mantle_core_has_command sysctl; then
		for sysctl_key in hw.memsize hw.physmem64 hw.physmem hw.realmem; do
			if value=$(sysctl -n "$sysctl_key" 2>/dev/null) &&
				__mantle_core_is_nonnegative_integer "$value" && ((value > 0)); then
				printf '%s\n' "$value"
				return 0
			fi
		done
	fi

	if mantle_core_has_command getconf; then
		if pages=$(getconf _PHYS_PAGES 2>/dev/null) &&
			page_size=$(getconf PAGE_SIZE 2>/dev/null) &&
			__mantle_core_is_nonnegative_integer "$pages" &&
			__mantle_core_is_nonnegative_integer "$page_size" &&
			((pages > 0 && page_size > 0)); then
			printf '%s\n' "$((pages * page_size))"
			return 0
		fi
	fi

	__mantle_core_error "total physical memory is unsupported on this platform"
	return 69
}

# -----------------------------------------------------------------------------
# User and group helpers
# -----------------------------------------------------------------------------

# @description Return whether a user exists in the system identity database.
# @arg $1 string User name from the portable account-name subset.
# @exitcode 0 If the user exists.
# @exitcode 1 If absent.
# @exitcode 64 If the name is invalid.
mantle_core_user_exists() {
	local user=${1-}

	if (($# != 1)) || ! __mantle_core_is_account_name "$user"; then
		__mantle_core_error "mantle_core_user_exists expects one portable user name"
		return 64
	fi

	id -u "$user" >/dev/null 2>&1
}

# @description Return whether a group exists using the host's supported database.
# @arg $1 string Group name from the portable account-name subset.
# @exitcode 0 If the group exists.
# @exitcode 1 If absent.
# @exitcode 64 If the name is invalid.
# @exitcode 69 If no supported group lookup is available.
mantle_core_group_exists() {
	local group=${1-}
	local group_name

	if (($# != 1)) || ! __mantle_core_is_account_name "$group"; then
		__mantle_core_error "mantle_core_group_exists expects one portable group name"
		return 64
	fi

	if mantle_core_has_command getent; then
		getent group "$group" >/dev/null 2>&1
		return $?
	fi

	if mantle_core_has_command dscl; then
		dscl . -read "/Groups/$group" >/dev/null 2>&1
		return $?
	fi

	if mantle_core_has_command pw; then
		pw groupshow "$group" >/dev/null 2>&1
		return $?
	fi

	if [[ -r "/etc/group" ]]; then
		while IFS=: read -r group_name _; do
			if [[ "$group_name" == "$group" ]]; then
				return 0
			fi
		done <"/etc/group"
		return 1
	fi

	__mantle_core_error "group lookup is unsupported on this platform"
	return 69
}

# @description Return whether a user belongs to a group.
# @arg $1 string Existing user name.
# @arg $2 string Existing group name.
# @exitcode 0 If the user is a member.
# @exitcode 1 If not a member.
# @exitcode 64 For invalid input.
mantle_core_user_in_group() {
	local user=${1-}
	local group=${2-}
	local memberships

	if (($# != 2)) || ! __mantle_core_is_account_name "$user" || ! __mantle_core_is_account_name "$group"; then
		__mantle_core_error "mantle_core_user_in_group expects USER GROUP"
		return 64
	fi
	if ! mantle_core_user_exists "$user"; then
		return 1
	fi
	if ! memberships=$(id -Gn "$user" 2>/dev/null); then
		return 1
	fi

	case " ${memberships} " in
		*" ${group} "*) return 0 ;;
		*) return 1 ;;
	esac
}

# @description Ensure a local system group exists when the platform supports it.
# @arg $1 string Group name from the portable account-name subset.
# @exitcode 0 If the group exists or was created.
# @exitcode 64 For invalid input.
# @exitcode 69 If group creation is unsupported.
# @exitcode 77 If creation requires root.
mantle_core_ensure_group() {
	local group=${1-}
	local lookup_status
	local platform

	if (($# != 1)) || ! __mantle_core_is_account_name "$group"; then
		__mantle_core_error "mantle_core_ensure_group expects one portable group name"
		return 64
	fi

	if mantle_core_group_exists "$group"; then
		return 0
	else
		lookup_status=$?
		if ((lookup_status != 1)); then
			return "$lookup_status"
		fi
	fi

	platform=$(mantle_core_platform) || {
		__mantle_core_error "cannot create group on an unknown platform"
		return 69
	}

	case "$platform" in
		linux)
			if ! mantle_core_has_command groupadd; then
				__mantle_core_error "group creation requires the groupadd command on Linux"
				return 69
			fi
			;;
		freebsd)
			if ! mantle_core_has_command pw; then
				__mantle_core_error "group creation requires the pw command on FreeBSD"
				return 69
			fi
			;;
		*)
			__mantle_core_error "automatic group creation is unsupported on platform: $platform"
			return 69
			;;
	esac

	__mantle_core_require_root || return $?

	case "$platform" in
		linux) groupadd "$group" ;;
		freebsd) pw groupadd "$group" ;;
	esac
}

# @description Ensure a user belongs to an existing supplementary group.
# @arg $1 string Existing user name.
# @arg $2 string Existing group name.
# @exitcode 0 If membership exists or was added.
# @exitcode 64 For invalid input.
# @exitcode 69 If membership mutation is unsupported.
# @exitcode 77 If mutation requires root.
mantle_core_ensure_group_membership() {
	local user=${1-}
	local group=${2-}
	local platform
	local lookup_status

	if (($# != 2)) || ! __mantle_core_is_account_name "$user" || ! __mantle_core_is_account_name "$group"; then
		__mantle_core_error "mantle_core_ensure_group_membership expects USER GROUP"
		return 64
	fi
	if ! mantle_core_user_exists "$user"; then
		__mantle_core_error "user does not exist: $user"
		return 64
	fi
	if mantle_core_group_exists "$group"; then
		:
	else
		lookup_status=$?
		if ((lookup_status == 1)); then
			__mantle_core_error "group does not exist: $group"
			return 64
		fi
		return "$lookup_status"
	fi
	if mantle_core_user_in_group "$user" "$group"; then
		return 0
	fi

	platform=$(mantle_core_platform) || return 69

	case "$platform" in
		linux)
			if ! mantle_core_has_command usermod; then
				__mantle_core_error "group membership changes require usermod on Linux"
				return 69
			fi
			;;
		freebsd)
			if ! mantle_core_has_command pw; then
				__mantle_core_error "group membership changes require pw on FreeBSD"
				return 69
			fi
			;;
		macos)
			if ! mantle_core_has_command dseditgroup; then
				__mantle_core_error "group membership changes require dseditgroup on macOS"
				return 69
			fi
			;;
		*)
			__mantle_core_error "group membership mutation is unsupported on platform: $platform"
			return 69
			;;
	esac

	__mantle_core_require_root || return $?

	case "$platform" in
		linux) usermod -a -G "$group" "$user" ;;
		freebsd) pw groupmod "$group" -m "$user" ;;
		macos) dseditgroup -o edit -a "$user" -t user "$group" ;;
	esac
}

# @description Ensure a local user exists and optionally joins a supplementary group.
# @arg $1 string User name from the portable account-name subset.
# @arg $2 string Optional supplementary group to create and join.
# @exitcode 0 If the requested state is satisfied.
# @exitcode 64 For invalid input.
# @exitcode 69 If user creation is unsupported.
# @exitcode 77 If creation or membership mutation requires root.
mantle_core_ensure_user() {
	local user=${1-}
	local group=${2-}
	local platform
	local user_missing=false
	local lookup_status

	if (($# < 1 || $# > 2)) || ! __mantle_core_is_account_name "$user"; then
		__mantle_core_error "mantle_core_ensure_user expects USER [SUPPLEMENTARY_GROUP]"
		return 64
	fi
	if [[ -n "$group" ]] && ! __mantle_core_is_account_name "$group"; then
		__mantle_core_error "supplementary group name is invalid: $group"
		return 64
	fi

	if mantle_core_user_exists "$user"; then
		user_missing=false
	else
		lookup_status=$?
		if ((lookup_status != 1)); then
			return "$lookup_status"
		fi
		user_missing=true
	fi

	if [[ "$user_missing" == true ]]; then
		platform=$(mantle_core_platform) || return 69

		case "$platform" in
			linux)
				if ! mantle_core_has_command useradd; then
					__mantle_core_error "user creation requires the useradd command on Linux"
					return 69
				fi
				;;
			freebsd)
				if ! mantle_core_has_command pw; then
					__mantle_core_error "user creation requires the pw command on FreeBSD"
					return 69
				fi
				;;
			*)
				__mantle_core_error "automatic user creation is unsupported on platform: $platform"
				return 69
				;;
		esac

		__mantle_core_require_root || return $?
	fi

	if [[ -n "$group" ]]; then
		mantle_core_ensure_group "$group" || return $?
	fi

	if [[ "$user_missing" == true ]]; then
		case "$platform" in
			linux) useradd "$user" || return $? ;;
			freebsd) pw useradd "$user" || return $? ;;
		esac
	fi

	if [[ -n "$group" ]]; then
		mantle_core_ensure_group_membership "$user" "$group"
	fi
}

MANTLE_CORE_LIBRARY_LOADED="1"

return 0
