#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide line-oriented array helpers compatible with Bash 3.2 and newer.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/array.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_ARRAY_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Return whether a value occurs in the supplied elements.
# @arg $1 string Value to find.
# @arg $@ string Array elements.
mantle_array_contains() {
	local query="${1:-}"
	local element=""

	if (($# < 2)); then
		return 64
	fi
	shift

	for element in "$@"; do
		[[ "${element}" == "${query}" ]] && return 0
	done

	return 1
}

# @description Print unique elements in first-seen order, one per line.
# @arg $@ string Array elements.
mantle_array_deduplicate() {
	local item=""
	local existing=""
	local duplicate="0"
	local -a unique_items=()

	for item in "$@"; do
		duplicate="0"
		for existing in "${unique_items[@]}"; do
			if [[ "${existing}" == "${item}" ]]; then
				duplicate="1"
				break
			fi
		done

		if [[ "${duplicate}" == "0" ]]; then
			unique_items+=("${item}")
		fi
	done

	if ((${#unique_items[@]} > 0)); then
		printf "%s\n" "${unique_items[@]}"
	fi
}

# @description Return whether no array elements were supplied.
mantle_array_is_empty() {
	(($# == 0))
}

# @description Join supplied elements with a delimiter.
# @arg $1 string Delimiter.
# @arg $@ string Array elements.
mantle_array_join() {
	local delimiter="${1:-}"
	local output=""
	local element=""
	local first="1"

	if (($# < 1)); then
		return 64
	fi
	shift

	for element in "$@"; do
		if [[ "${first}" == "1" ]]; then
			output="${element}"
			first="0"
		else
			output+="${delimiter}${element}"
		fi
	done

	printf "%s\n" "${output}"
}

# @description Print supplied elements in reverse order, one per line.
mantle_array_reverse() {
	local -a elements=("$@")
	local index=0

	for ((index = ${#elements[@]} - 1; index >= 0; index--)); do
		printf "%s\n" "${elements[index]}"
	done
}

# @description Print one pseudorandomly selected array element.
# @exitcode 64 No elements were supplied.
mantle_array_random_element() {
	local -a elements=("$@")

	if (($# == 0)); then
		return 64
	fi

	printf "%s\n" "${elements[RANDOM % $#]}"
}

# @description Sort supplied text elements in bytewise ascending order.
mantle_array_sort() {
	if (($# == 0)); then
		return 0
	fi

	printf "%s\n" "$@" | LC_ALL=C sort
}

# @description Sort supplied text elements in bytewise descending order.
mantle_array_sort_reverse() {
	if (($# == 0)); then
		return 0
	fi

	printf "%s\n" "$@" | LC_ALL=C sort -r
}

# @description Sort supplied numeric elements in ascending order.
mantle_array_sort_numeric() {
	local element=""

	for element in "$@"; do
		if [[ ! "${element}" =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]; then
			return 64
		fi
	done

	if (($# > 0)); then
		printf "%s\n" "$@" | LC_ALL=C sort -n
	fi
}

# @description Merge two indexed arrays referenced as name[@].
# @arg $1 string First array reference.
# @arg $2 string Second array reference.
mantle_array_merge() {
	local first_reference="${1:-}"
	local second_reference="${2:-}"
	local -a first_values=()
	local -a second_values=()

	if (($# != 2)) ||
		[[ ! "${first_reference}" =~ ^[A-Za-z_][A-Za-z0-9_]*\[@\]$ ]] ||
		[[ ! "${second_reference}" =~ ^[A-Za-z_][A-Za-z0-9_]*\[@\]$ ]]; then
		return 64
	fi

	first_values=("${!first_reference}")
	second_values=("${!second_reference}")
	if ((${#first_values[@]} + ${#second_values[@]} > 0)); then
		printf "%s\n" "${first_values[@]}" "${second_values[@]}"
	fi
}

MANTLE_ARRAY_LIBRARY_LOADED="1"

return 0
