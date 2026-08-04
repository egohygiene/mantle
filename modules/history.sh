#!/usr/bin/env bash
# shellcheck shell=bash
#
# Configure interactive Bash/Zsh history and supported REPL history files under
# XDG_STATE_HOME. This module owns history policy; runtime adapters do not.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/history.sh is internal and must be sourced\n" >&2
	exit 64
elif [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] modules/history.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INTERACTIVE:-0}" != "1" ]]; then
	return 0
fi

if [[ -z "${XDG_STATE_HOME:-}" ]]; then
	printf "[mantle:error] history: XDG_STATE_HOME is required\n" >&2
	return 1
fi

__mantle_history_size="${MANTLE_HISTORY_SIZE:-50000}"

case "${__mantle_history_size}" in
"" | *[!0-9]* | 0)
	printf "[mantle:warn] invalid MANTLE_HISTORY_SIZE; using 50000\n" >&2
	__mantle_history_size="50000"
	;;
esac

__mantle_history_root="${XDG_STATE_HOME}/history"
__mantle_history_repl_root="${__mantle_history_root}/repl"

if ! mkdir -p -- "${__mantle_history_repl_root}"; then
	printf "[mantle:error] history: unable to create history directory: %s\n" \
		"${__mantle_history_repl_root}" >&2
	unset __mantle_history_repl_root
	unset __mantle_history_root
	unset __mantle_history_size
	return 1
fi

case "${MANTLE_SHELL_NAME:-unknown}" in
bash)
	if ! mkdir -p -- "${__mantle_history_root}/bash"; then
		printf "[mantle:error] history: unable to create Bash history directory\n" >&2
		unset __mantle_history_repl_root
		unset __mantle_history_root
		unset __mantle_history_size
		return 1
	fi

	export HISTFILE="${__mantle_history_root}/bash/history"
	export HISTSIZE="${__mantle_history_size}"
	export HISTFILESIZE="${__mantle_history_size}"
	export HISTCONTROL="${HISTCONTROL:-ignoreboth:erasedups}"
	shopt -s histappend cmdhist lithist
	;;
zsh)
	if ! mkdir -p -- "${__mantle_history_root}/zsh"; then
		printf "[mantle:error] history: unable to create Zsh history directory\n" >&2
		unset __mantle_history_repl_root
		unset __mantle_history_root
		unset __mantle_history_size
		return 1
	fi

	export HISTFILE="${__mantle_history_root}/zsh/history"
	export HISTSIZE="${__mantle_history_size}"
	export SAVEHIST="${__mantle_history_size}"
	setopt APPEND_HISTORY
	setopt EXTENDED_HISTORY
	setopt HIST_IGNORE_DUPS
	setopt HIST_IGNORE_SPACE
	setopt HIST_REDUCE_BLANKS
	setopt INC_APPEND_HISTORY
	;;
*)
	printf "[mantle:warn] history: no shell-history policy exists for %s\n" \
		"${MANTLE_SHELL_NAME:-unknown}" >&2
	;;
esac

# Language REPLs and runtimes.
export NODE_REPL_HISTORY="${NODE_REPL_HISTORY:-${__mantle_history_repl_root}/node}"
export JULIA_HISTORY="${JULIA_HISTORY:-${__mantle_history_repl_root}/julia}"
export R_HISTFILE="${R_HISTFILE:-${__mantle_history_repl_root}/r}"
export OCTAVE_HISTFILE="${OCTAVE_HISTFILE:-${__mantle_history_repl_root}/octave}"
export CALCHISTFILE="${CALCHISTFILE:-${__mantle_history_repl_root}/calc}"

# Database clients.
export REDISCLI_HISTFILE="${REDISCLI_HISTFILE:-${__mantle_history_repl_root}/redis}"
export SQLITE_HISTORY="${SQLITE_HISTORY:-${__mantle_history_repl_root}/sqlite}"
export PSQL_HISTORY="${PSQL_HISTORY:-${__mantle_history_repl_root}/postgresql}"
export PGSQL_HISTORY="${PGSQL_HISTORY:-${__mantle_history_repl_root}/pgsql}"
export MYSQL_HISTFILE="${MYSQL_HISTFILE:-${__mantle_history_repl_root}/mysql}"
export MYSQL_HISTSIZE="${MYSQL_HISTSIZE:-${__mantle_history_size}}"

# System and debugging tools.
export LESSHISTFILE="${LESSHISTFILE:-${__mantle_history_repl_root}/less}"
export LESSHISTSIZE="${LESSHISTSIZE:-${__mantle_history_size}}"
export GDBHISTFILE="${GDBHISTFILE:-${__mantle_history_repl_root}/gdb}"
export UNITS_HISTORY_FILE="${UNITS_HISTORY_FILE:-${__mantle_history_repl_root}/units}"
export RLWRAP_HOME="${RLWRAP_HOME:-${__mantle_history_repl_root}/rlwrap}"

unset __mantle_history_repl_root
unset __mantle_history_root
unset __mantle_history_size

return 0
