# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Explicit prompting replacements for familiar file-management commands.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/aliases-safety.sh is internal and must be sourced\n" >&2
	exit 64
fi
if [[ "${MANTLE_INTERACTIVE:-0}" != "1" ]]; then return 0; fi

alias cp="command cp -iv"
alias mv="command mv -iv"
alias rm="command rm -i"

return 0
