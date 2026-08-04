#!/usr/bin/env bash
# shellcheck shell=bash
#
# Define portable, low-surprise interactive aliases and helper functions for
# Bash and Zsh.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/aliases.sh is internal and must be sourced\n" >&2
	exit 64
elif [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] modules/aliases.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INTERACTIVE:-0}" != "1" ]]; then
	return 0
fi

# @description Replace the current shell with a fresh login shell.
# @exitcode 64 SHELL was unset or did not identify an executable file.
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
# @arg $1 string Directory to create and enter.
# @exitcode 0 The directory was created, if necessary, and entered.
# @exitcode 64 Exactly one directory argument was not provided.
# @exitcode 1 Directory creation or the directory change failed.
mantle_mkcd() {
	if (($# != 1)); then
		printf "Usage: mkcd DIRECTORY\n" >&2
		return 64
	fi

	mkdir -p -- "$1" || return 1
	builtin cd -- "$1" || return 1
}

# @description Print PATH entries one per line in resolution order.
# @stdout Zero or more PATH entries.
# @exitcode 0 PATH was printed.
# @exitcode 64 Unexpected arguments were provided.
mantle_print_path() {
	local remaining_path="${PATH:-}"
	local path_entry=""

	if (($# != 0)); then
		printf "[mantle:error] mantle_print_path does not accept arguments\n" >&2
		return 64
	fi

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

# @description Invoke man with a readable color palette when less is the pager.
# @arg $@ string Arguments forwarded to man.
# @exitcode 0 man completed successfully.
# @exitcode * The status returned by man.
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

alias c="clear"
alias cls="clear"
alias environment="printenv | LC_ALL=C sort"
alias path="mantle_print_path"

alias now="date +%Y-%m-%dT%H:%M:%S"
alias unow="date -u +%Y-%m-%dT%H:%M:%S"
alias nowdate="date +%Y-%m-%d"
alias unowdate="date -u +%Y-%m-%d"
alias nowtime="date +%H:%M:%S"
alias unowtime="date -u +%H:%M:%S"
alias timestamp="date -u +%s"
alias week="date +%G-W%V"
alias weekday="date +%u"
alias month="date +%B"
alias year="date +%Y"

alias clone="git clone"
alias ascii="man ascii"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

if command -v eza >/dev/null 2>&1; then
	alias ls="eza --group-directories-first"
	alias ll="eza --all --long --group-directories-first --git"
	alias lt="eza --tree --icons=auto --git"
	alias lss="eza --long --header --total-size --icons=auto --sort=size"
else
	# The portable short options are required because BSD ls does not implement
	# GNU ls long-form flags.
	alias ll="ls -al"
fi

if command -v dust >/dev/null 2>&1; then
	alias dud="dust --depth 1"
fi

if ! command -v md5sum >/dev/null 2>&1 && command -v md5 >/dev/null 2>&1; then
	alias md5sum="md5"
fi

if ! command -v sha1sum >/dev/null 2>&1 && command -v shasum >/dev/null 2>&1; then
	alias sha1sum="shasum --algorithm 1"
fi

if command -v python3 >/dev/null 2>&1; then
	alias pretty-json="python3 -m json.tool --sort-keys --no-ensure-ascii"
fi

if command -v gallery-dl >/dev/null 2>&1; then
	alias gallery-dl="gallery-dl --config \"\${XDG_CONFIG_HOME}/gallery-dl/config.json\""
fi

if command -v feh >/dev/null 2>&1; then
	alias photos="feh --auto-zoom --image-bg black --randomize --recursive --scale-down ."
fi

if command -v mount >/dev/null 2>&1 && command -v column >/dev/null 2>&1; then
	alias mounts="mount | column -t"
fi

alias reload="mantle_reload_shell"
alias mkcd="mantle_mkcd"
alias man="mantle_man"

# These aliases add prompts while changing familiar command behavior, so they
# require explicit consent.
if [[ "${MANTLE_ENABLE_SAFETY_ALIASES:-0}" == "1" ]]; then
	alias cp="cp -i"
	alias mv="mv -i"
	alias rm="rm -i"
fi

return 0
