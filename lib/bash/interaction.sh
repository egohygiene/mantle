#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide explicit prompt helpers; sourcing this file never prompts.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/bash/interaction.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INTERACTION_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Prompt for a yes-or-no decision.
# @arg $1 string Question.
# @arg $2 string Optional yes or no default.
# @exitcode 0 The answer was yes.
# @exitcode 1 The answer was no or input ended.
# @exitcode 64 Usage is invalid.
mantle_interaction_confirm() {
	local question="${1:-}"
	local default_answer="${2:-}"
	local normalized_default=""
	local response=""

	if (($# < 1 || $# > 2)) || [[ -z "${question}" ]]; then
		return 64
	fi

	case "${default_answer}" in
		"") normalized_default="" ;;
		y | Y | yes | YES | Yes) normalized_default="yes" ;;
		n | N | no | NO | No) normalized_default="no" ;;
		*) return 64 ;;
	esac

	while :; do
		case "${normalized_default}" in
			yes) printf "%s [Y/n] " "${question}" >&2 ;;
			no) printf "%s [y/N] " "${question}" >&2 ;;
			*) printf "%s [y/n] " "${question}" >&2 ;;
		esac

		if ! IFS= read -r response; then
			return 1
		fi
		[[ -z "${response}" ]] && response="${normalized_default}"

		case "${response}" in
			y | Y | yes | YES | Yes) return 0 ;;
			n | N | no | NO | No) return 1 ;;
		esac
	done
}

# @description Prompt for a free-form response and print only the answer.
# @arg $1 string Question.
# @arg $2 string Optional default answer.
# @exitcode 1 Input ended before a value was provided.
mantle_interaction_prompt() {
	local question="${1:-}"
	local default_answer="${2:-}"
	local response=""

	if (($# < 1 || $# > 2)) || [[ -z "${question}" ]]; then
		return 64
	fi

	while :; do
		printf "%s" "${question}" >&2
		if (($# == 2)); then
			printf " [%s]" "${default_answer}" >&2
		fi
		printf " " >&2

		if ! IFS= read -r response; then
			return 1
		fi

		if [[ -n "${response}" ]]; then
			printf "%s\n" "${response}"
			return 0
		fi
		if (($# == 2)); then
			printf "%s\n" "${default_answer}"
			return 0
		fi
	done
}

MANTLE_INTERACTION_LIBRARY_LOADED="1"

return 0
