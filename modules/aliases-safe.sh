# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Portable, low-surprise interactive helpers selected by an explicit focused alias policy.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/aliases-safe.sh is internal and must be sourced\n" >&2
	exit 64
fi
if [[ "${MANTLE_INTERACTIVE:-0}" != "1" ]]; then return 0; fi

# @description Replace the current shell with a fresh login shell.
mantle_reload_shell() {
	local shell_path="${SHELL:-}"
	if [[ -z "${shell_path}" || ! -x "${shell_path}" ]]; then
		printf "[mantle:error] cannot reload an unavailable shell: %s\n" \
			"${shell_path:-<unset>}" >&2
		return 64
	fi
	exec "${shell_path}" --login
}

# @description Create a directory and change the current shell into it.
mantle_mkcd() {
	if (($# != 1)); then
		printf "Usage: mkcd DIRECTORY\n" >&2
		return 64
	fi
	mkdir -p -- "$1" || return 1
	builtin cd -- "$1" || return 1
}

# @description Print PATH entries one per line in resolution order.
mantle_print_path() {
	local remaining_path="${PATH:-}"
	local path_entry=""
	while [[ -n "${remaining_path}" ]]; do
		if [[ "${remaining_path}" == *:* ]]; then
			path_entry="${remaining_path%%:*}"
			remaining_path="${remaining_path#*:}"
		else
			path_entry="${remaining_path}"
			remaining_path=""
		fi
		printf "%s\n" "${path_entry}"
	done
}

# @description Print PATH entries in locale-independent sort order.
mantle_print_sorted_path() {
	if (($# != 0)); then return 64; fi
	mantle_print_path | LC_ALL=C sort
}

# @description Invoke man with a readable color palette when less is the pager.
mantle_man() {
	LESS_TERMCAP_mb=$'\E[01;31m' \
		LESS_TERMCAP_md=$'\E[01;38;5;74m' \
		LESS_TERMCAP_me=$'\E[0m' \
		LESS_TERMCAP_se=$'\E[0m' \
		LESS_TERMCAP_so=$'\E[38;5;246m' \
		LESS_TERMCAP_ue=$'\E[0m' \
		LESS_TERMCAP_us=$'\E[04;38;5;146m' \
		command man "$@"
}

# @description Print the current local timestamp as ISO 8601 with an offset.
mantle_now_iso() {
	command date "+%Y-%m-%dT%H:%M:%S%z" |
		sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/'
}

# @description Copy standard input to the system clipboard.
mantle_set_clipboard() {
	if command -v pbcopy >/dev/null 2>&1; then
		command pbcopy
	elif command -v wl-copy >/dev/null 2>&1; then
		command wl-copy
	elif command -v xclip >/dev/null 2>&1; then
		command xclip -selection clipboard
	elif command -v xsel >/dev/null 2>&1; then
		command xsel --clipboard --input
	else
		printf "[mantle:error] no supported clipboard command is available\n" >&2
		return 69
	fi
}

# @description Print the current contents of the system clipboard.
mantle_get_clipboard() {
	if command -v pbpaste >/dev/null 2>&1; then
		command pbpaste
	elif command -v wl-paste >/dev/null 2>&1; then
		command wl-paste
	elif command -v xclip >/dev/null 2>&1; then
		command xclip -selection clipboard -out
	elif command -v xsel >/dev/null 2>&1; then
		command xsel --clipboard --output
	else
		printf "[mantle:error] no supported clipboard command is available\n" >&2
		return 69
	fi
}

alias .="pwd"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias mkcd="mantle_mkcd"
alias mkdirp="command mkdir -p"
alias path="mantle_print_path"
alias path-sorted="mantle_print_sorted_path"
alias reload="mantle_reload_shell"
alias now="command date +%Y-%m-%dT%H:%M:%S"
alias now-iso="mantle_now_iso"
alias unow="command date -u +%Y-%m-%dT%H:%M:%S"
alias nowdate="command date +%Y-%m-%d"
alias timestamp="command date -u +%s"
alias setclip="mantle_set_clipboard"
alias getclip="mantle_get_clipboard"

if command -v eza >/dev/null 2>&1; then
	alias ll="command eza --all --long --header --group --icons=auto --git --group-directories-first"
	alias la="command eza --all --icons=auto --group-directories-first"
	alias l="command eza --grid --classify --icons=auto --group-directories-first"
else
	alias ll="command ls -alF"
	alias la="command ls -A"
	alias l="command ls -CF"
fi

# Prevent adb from consulting ~/.android after ANDROID_USER_HOME has migrated.
if command -v adb >/dev/null 2>&1 && [[ -n "${ANDROID_USER_HOME:-}" ]]; then
	alias adb='HOME="$ANDROID_USER_HOME" command adb'
fi

# feh otherwise recreates ~/.fehbg each time a background is selected.
if command -v feh >/dev/null 2>&1; then
	alias feh="command feh --no-fehbg"
fi

return 0
