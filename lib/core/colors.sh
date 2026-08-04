#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034 # Variables are this library's public API.
#
# Define Mantle's terminal-color contract without emitting output.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/core/colors.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_COLORS_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

: "${MANTLE_COLOR_MODE:=auto}"

case "${MANTLE_COLOR_MODE}" in
	always)
		MANTLE_COLORS_ENABLED="1"
		;;
	never)
		MANTLE_COLORS_ENABLED="0"
		;;
	auto)
		if [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
			MANTLE_COLORS_ENABLED="1"
		else
			MANTLE_COLORS_ENABLED="0"
		fi
		;;
	*)
		printf "[mantle:error] invalid MANTLE_COLOR_MODE: %s\n" \
			"${MANTLE_COLOR_MODE}" >&2
		return 64
		;;
esac

if [[ "${MANTLE_COLORS_ENABLED}" == "1" ]]; then
	MANTLE_COLOR_RESET="\033[0m"
	MANTLE_COLOR_BOLD="\033[1m"
	MANTLE_COLOR_DIM="\033[2m"
	MANTLE_COLOR_RED="\033[31m"
	MANTLE_COLOR_GREEN="\033[32m"
	MANTLE_COLOR_YELLOW="\033[33m"
	MANTLE_COLOR_BLUE="\033[34m"
	MANTLE_COLOR_MAGENTA="\033[35m"
	MANTLE_COLOR_CYAN="\033[36m"
	MANTLE_COLOR_WHITE="\033[37m"
	MANTLE_COLOR_BOLD_RED="\033[1;31m"
	MANTLE_COLOR_BOLD_GREEN="\033[1;32m"
	MANTLE_COLOR_BOLD_YELLOW="\033[1;33m"
	MANTLE_COLOR_BOLD_BLUE="\033[1;34m"
	MANTLE_COLOR_BOLD_CYAN="\033[1;36m"
else
	MANTLE_COLOR_RESET=""
	MANTLE_COLOR_BOLD=""
	MANTLE_COLOR_DIM=""
	MANTLE_COLOR_RED=""
	MANTLE_COLOR_GREEN=""
	MANTLE_COLOR_YELLOW=""
	MANTLE_COLOR_BLUE=""
	MANTLE_COLOR_MAGENTA=""
	MANTLE_COLOR_CYAN=""
	MANTLE_COLOR_WHITE=""
	MANTLE_COLOR_BOLD_RED=""
	MANTLE_COLOR_BOLD_GREEN=""
	MANTLE_COLOR_BOLD_YELLOW=""
	MANTLE_COLOR_BOLD_BLUE=""
	MANTLE_COLOR_BOLD_CYAN=""
fi

MANTLE_COLORS_LIBRARY_LOADED="1"

return 0
