#!/usr/bin/env bash
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# shellcheck disable=SC2249 # Closed case statements intentionally treat unmatched values as no-ops.
# Generate shell completion definitions for the public Mantle CLI.

set -o errexit
set -o nounset
set -o pipefail

# @description Describe completion generation without initializing the runtime.
# @stdout Supported native completion targets.
mantle_completion_usage() {
	printf "%s\n" \
		"Usage: mantle completion SHELL" \
		"" \
		"Generate completion definitions for bash, zsh, or fish."
}

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	printf "[mantle:error] MANTLE_ROOT is required for command dispatch\n" >&2
	exit 70
fi

if (($# == 0)); then
	mantle_completion_usage
	exit 0
fi

case "$1" in
--summary)
	printf "Generate shell completion definitions.\n"
	exit 0
	;;
--help | -h)
	mantle_completion_usage
	exit 0
	;;
esac

if (($# != 1)); then
	printf "[mantle:error] completion requires exactly one shell name\n" >&2
	mantle_completion_usage >&2
	exit 64
fi

mantle_completion_commands=""
for mantle_completion_path in "${MANTLE_ROOT}/libexec/mantle/commands"/*.sh; do
	[[ -f "${mantle_completion_path}" && -x "${mantle_completion_path}" ]] || continue
	mantle_completion_name="${mantle_completion_path##*/}"
	mantle_completion_name="${mantle_completion_name%.sh}"
	[[ "${mantle_completion_name}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || continue
	mantle_completion_commands="${mantle_completion_commands}${mantle_completion_commands:+ }${mantle_completion_name}"
done

mantle_completion_installers=""
for mantle_completion_path in "${MANTLE_ROOT}/libexec/mantle/installers"/*.sh; do
	[[ -f "${mantle_completion_path}" && -x "${mantle_completion_path}" ]] || continue
	mantle_completion_name="${mantle_completion_path##*/}"
	mantle_completion_name="${mantle_completion_name%.sh}"
	[[ "${mantle_completion_name}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || continue
	mantle_completion_installers="${mantle_completion_installers}${mantle_completion_installers:+ }${mantle_completion_name}"
done
mantle_completion_install_arguments="--list --assurance --help ${mantle_completion_installers}"
mantle_completion_profiles=""
while IFS=$'\t' read -r mantle_completion_name _mantle_completion_profile_metadata; do
	case "${mantle_completion_name}" in
	core | interactive | workstation | container | ci | full)
		mantle_completion_profiles="${mantle_completion_profiles}${mantle_completion_profiles:+ }${mantle_completion_name}"
		;;
	esac
done <"${MANTLE_ROOT}/config/profiles.tsv"

case "$1" in
bash)
	# The expressions below belong to generated Bash.
	# shellcheck disable=SC2016
	printf '%s\n' \
		'_mantle_completion() {' \
		'  local current previous' \
		'  COMPREPLY=()' \
		'  current="${COMP_WORDS[COMP_CWORD]}"' \
		'  previous=""' \
		'  if ((COMP_CWORD > 0)); then previous="${COMP_WORDS[COMP_CWORD-1]}"; fi' \
		'  if [[ "${COMP_CWORD}" -eq 1 ]]; then' \
		"    COMPREPLY=( \$(compgen -W \"${mantle_completion_commands}\" -- \"\${current}\") )" \
		'  elif [[ "${COMP_WORDS[1]}" == "help" && "${COMP_CWORD}" -eq 2 ]]; then' \
		"    COMPREPLY=( \$(compgen -W \"${mantle_completion_commands}\" -- \"\${current}\") )" \
		'  elif [[ "${COMP_WORDS[1]}" == "install" && "${COMP_CWORD}" -eq 2 ]]; then' \
		"    COMPREPLY=( \$(compgen -W \"${mantle_completion_install_arguments}\" -- \"\${current}\") )" \
		'  elif [[ "${COMP_WORDS[1]}" == "install" && "${previous}" == "--assurance" ]]; then' \
		"    COMPREPLY=( \$(compgen -W \"${mantle_completion_installers}\" -- \"\${current}\") )" \
		'  elif [[ "${COMP_WORDS[1]}" == "completion" && "${COMP_CWORD}" -eq 2 ]]; then' \
		'    COMPREPLY=( $(compgen -W "bash zsh fish" -- "${current}") )' \
		'  elif [[ "${COMP_WORDS[1]}" == "config" && "${COMP_CWORD}" -eq 2 ]]; then' \
		'    COMPREPLY=( $(compgen -W "list-profiles path validate show explain" -- "${current}") )' \
		'  elif [[ "${COMP_WORDS[1]}" == "profiles" && "${COMP_CWORD}" -eq 2 ]]; then' \
		'    COMPREPLY=( $(compgen -W "list show validate" -- "${current}") )' \
		'  elif [[ "${COMP_WORDS[1]}" == "catalog" && "${COMP_CWORD}" -eq 2 ]]; then' \
		'    COMPREPLY=( $(compgen -W "list validate" -- "${current}") )' \
		'  elif [[ "${COMP_WORDS[1]}" == "storage" && "${COMP_CWORD}" -eq 2 ]]; then' \
		'    COMPREPLY=( $(compgen -W "disk directory repo objects large-files" -- "${current}") )' \
		'  elif [[ ( "${COMP_WORDS[1]}" == "profiles" && "${previous}" == "show" ) || ( "${COMP_WORDS[1]}" == "catalog" && "${previous}" == "--profile" ) ]]; then' \
		"    COMPREPLY=( \$(compgen -W \"${mantle_completion_profiles}\" -- \"\${current}\") )" \
		'  elif [[ "${COMP_WORDS[1]}" == "fastfetch" && "${COMP_CWORD}" -eq 2 ]]; then' \
		'    COMPREPLY=( $(compgen -W "runtime workspace toolchains contexts" -- "${current}") )' \
		'  fi' \
		'}' \
		'complete -F _mantle_completion mantle'
	;;
zsh)
	# $words belongs to generated Zsh.
	# shellcheck disable=SC2016
	printf '#compdef mantle\n_mantle_completion() {\n  local state\n  _arguments "1:command:(%s)" "*::argument:->args"\n  case $words[2] in\n    help) compadd -- %s ;;\n    install) compadd -- %s ;;\n    completion) compadd -- bash zsh fish ;;\n    config) compadd -- list-profiles path validate show explain ;;\n    profiles) compadd -- list show validate ;;\n    catalog) compadd -- list validate ;;\n    storage) compadd -- disk directory repo objects large-files ;;\n    fastfetch) compadd -- runtime workspace toolchains contexts ;;\n  esac\n}\ncompdef _mantle_completion mantle\n' \
		"${mantle_completion_commands}" "${mantle_completion_commands}" "${mantle_completion_install_arguments}"
	;;
fish)
	printf "complete -c mantle -f -n '__fish_use_subcommand' -a '%s'\n" "${mantle_completion_commands}"
	printf "complete -c mantle -f -n '__fish_seen_subcommand_from help' -a '%s'\n" "${mantle_completion_commands}"
	printf "complete -c mantle -f -n '__fish_seen_subcommand_from install' -a '%s'\n" "${mantle_completion_install_arguments}"
	printf "complete -c mantle -f -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'\n"
	printf "complete -c mantle -f -n '__fish_seen_subcommand_from config' -a 'list-profiles path validate show explain'\n"
	printf "complete -c mantle -f -n '__fish_seen_subcommand_from profiles' -a 'list show validate'\n"
	printf "complete -c mantle -f -n '__fish_seen_subcommand_from catalog' -a 'list validate'\n"
	printf "complete -c mantle -f -n '__fish_seen_subcommand_from storage' -a 'disk directory repo objects large-files'\n"
	printf "complete -c mantle -f -n '__fish_seen_subcommand_from fastfetch' -a 'runtime workspace toolchains contexts'\n"
	;;
*)
	printf "[mantle:error] unsupported completion shell; choose bash, zsh, or fish\n" >&2
	mantle_completion_usage >&2
	exit 64
	;;
esac
