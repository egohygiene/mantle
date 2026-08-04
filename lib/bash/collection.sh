#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide safe higher-order helpers for newline-delimited input.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/collection.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_COLLECTION_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_collection_validate_callback() {
	local callback_name="${1:-}"

	if [[ ! "${callback_name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
		return 64
	fi

	command -v "${callback_name}" >/dev/null 2>&1 || return 127
}

# @description Invoke a callback for every newline-delimited input element.
# @arg $1 string Function or command name.
mantle_collection_each() {
	local callback_name="${1:-}"
	local item=""
	local callback_status=0

	if (($# != 1)); then
		return 64
	fi
	__mantle_collection_validate_callback "${callback_name}" || return $?

	while IFS= read -r item || [[ -n "${item}" ]]; do
		if "${callback_name}" "${item}"; then
			:
		else
			callback_status=$?
			return "${callback_status}"
		fi
	done
}

# @description Return true when a predicate matches every input element.
mantle_collection_every() {
	local callback_name="${1:-}"
	local item=""

	if (($# != 1)); then
		return 64
	fi
	__mantle_collection_validate_callback "${callback_name}" || return $?

	while IFS= read -r item || [[ -n "${item}" ]]; do
		"${callback_name}" "${item}" >/dev/null || return 1
	done

	return 0
}

# @description Print input elements for which a predicate succeeds.
mantle_collection_filter() {
	local callback_name="${1:-}"
	local item=""

	if (($# != 1)); then
		return 64
	fi
	__mantle_collection_validate_callback "${callback_name}" || return $?

	while IFS= read -r item || [[ -n "${item}" ]]; do
		if "${callback_name}" "${item}" >/dev/null; then
			printf "%s\n" "${item}"
		fi
	done
}

# @description Print the first input element for which a predicate succeeds.
mantle_collection_find() {
	local callback_name="${1:-}"
	local item=""

	if (($# != 1)); then
		return 64
	fi
	__mantle_collection_validate_callback "${callback_name}" || return $?

	while IFS= read -r item || [[ -n "${item}" ]]; do
		if "${callback_name}" "${item}" >/dev/null; then
			printf "%s\n" "${item}"
			return 0
		fi
	done

	return 1
}

# @description Pass all newline-delimited input elements to one callback call.
mantle_collection_invoke() {
	local callback_name="${1:-}"
	local item=""
	local -a arguments=()

	if (($# != 1)); then
		return 64
	fi
	__mantle_collection_validate_callback "${callback_name}" || return $?

	while IFS= read -r item || [[ -n "${item}" ]]; do
		arguments+=("${item}")
	done

	"${callback_name}" "${arguments[@]}"
}

# @description Apply a callback to every newline-delimited input element.
mantle_collection_map() {
	local callback_name="${1:-}"
	local item=""
	local callback_status=0

	if (($# != 1)); then
		return 64
	fi
	__mantle_collection_validate_callback "${callback_name}" || return $?

	while IFS= read -r item || [[ -n "${item}" ]]; do
		if "${callback_name}" "${item}"; then
			:
		else
			callback_status=$?
			return "${callback_status}"
		fi
	done
}

# @description Print input elements for which a predicate fails.
mantle_collection_reject() {
	local callback_name="${1:-}"
	local item=""

	if (($# != 1)); then
		return 64
	fi
	__mantle_collection_validate_callback "${callback_name}" || return $?

	while IFS= read -r item || [[ -n "${item}" ]]; do
		if ! "${callback_name}" "${item}" >/dev/null; then
			printf "%s\n" "${item}"
		fi
	done
}

# @description Return true when a predicate matches at least one input element.
mantle_collection_some() {
	local callback_name="${1:-}"
	local item=""

	if (($# != 1)); then
		return 64
	fi
	__mantle_collection_validate_callback "${callback_name}" || return $?

	while IFS= read -r item || [[ -n "${item}" ]]; do
		"${callback_name}" "${item}" >/dev/null && return 0
	done

	return 1
}

MANTLE_COLLECTION_LIBRARY_LOADED="1"

return 0
