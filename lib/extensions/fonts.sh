#!/usr/bin/env bash
# shellcheck shell=bash
#
# Provide opt-in, cross-platform font inventory helpers.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/extensions/fonts.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_FONTS_EXTENSION_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_fonts_platform() {
	if [[ -n "${MANTLE_OS_FAMILY:-}" ]]; then
		printf "%s\n" "${MANTLE_OS_FAMILY}"
		return 0
	fi

	case "$(uname -s 2>/dev/null)" in
	Darwin) printf "darwin\n" ;;
	Linux) printf "linux\n" ;;
	CYGWIN* | MINGW* | MSYS*) printf "windows\n" ;;
	*) printf "unknown\n" ;;
	esac
}

__mantle_fonts_list_linux_tsv() {
	command -v fc-list >/dev/null 2>&1 || return 127
	fc-list --format "%{family[0]}\t%{file}\n" 2>/dev/null
}

__mantle_fonts_list_macos_tsv() {
	command -v system_profiler >/dev/null 2>&1 || return 127
	system_profiler SPFontsDataType 2>/dev/null |
		awk -F: '
			/^[[:space:]]*Full Name:/ {
				name = substr($0, index($0, ":") + 1)
				sub(/^[[:space:]]+/, "", name)
			}
			/^[[:space:]]*Location:/ {
				path = substr($0, index($0, ":") + 1)
				sub(/^[[:space:]]+/, "", path)
				if (name != "" && path != "") {
					printf "%s\t%s\n", name, path
					name = ""
					path = ""
				}
			}'
}

__mantle_fonts_list_windows_tsv() {
	command -v powershell.exe >/dev/null 2>&1 || return 127
	powershell.exe -NoLogo -NoProfile -NonInteractive -Command - 2>/dev/null <<'POWERSHELL'
$fontKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
$fontProperties = Get-ItemProperty $fontKey
$fontProperties.PSObject.Properties |
    Where-Object { $_.Name -notlike "PS*" } |
    ForEach-Object { "{0}`t{1}" -f $_.Name, $_.Value }
POWERSHELL
}

__mantle_fonts_list_tsv() {
	case "$(__mantle_fonts_platform)" in
	linux) __mantle_fonts_list_linux_tsv ;;
	darwin) __mantle_fonts_list_macos_tsv ;;
	windows) __mantle_fonts_list_windows_tsv ;;
	*) return 69 ;;
	esac
}

# @description Print installed fonts as family-name, colon, and file path.
mantle_fonts_list() {
	local font_inventory=""

	font_inventory="$(__mantle_fonts_list_tsv)" || return $?
	if [[ -n "${font_inventory}" ]]; then
		printf "%s\n" "${font_inventory}" | awk -F "\t" '{ print $1 ": " $2 }'
	fi
}

# @description Print installed fonts as a JSON array.
mantle_fonts_list_json() {
	local font_inventory=""

	command -v jq >/dev/null 2>&1 || return 127
	font_inventory="$(__mantle_fonts_list_tsv)" || return $?
	printf "%s" "${font_inventory}" |
		jq --raw-input --slurp '
			split("\n")
			| map(select(length > 0) | split("\t") | {name: .[0], path: .[1]})'
}

MANTLE_FONTS_EXTENSION_LOADED="1"

return 0
