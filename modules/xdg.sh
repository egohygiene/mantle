#!/usr/bin/env bash
# shellcheck shell=bash
#
# Establish Mantle's XDG Base Directory contract on Linux, macOS, and
# containerized environments.
#
# Reference: https://specifications.freedesktop.org/basedir-spec/latest/

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/xdg.sh is internal and must be sourced\n" >&2
	exit 64
elif [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] modules/xdg.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ -z "${HOME:-}" || "${HOME}" != /* ]]; then
	printf "[mantle:error] xdg: HOME must be an absolute path\n" >&2
	return 1
fi

__mantle_xdg_config_default="${HOME}/.config"
__mantle_xdg_cache_default="${HOME}/.cache"
__mantle_xdg_data_default="${HOME}/.local/share"
__mantle_xdg_state_default="${HOME}/.local/state"

if [[ -n "${XDG_CONFIG_HOME:-}" && "${XDG_CONFIG_HOME}" != /* ]]; then
	printf "[mantle:warn] XDG_CONFIG_HOME must be absolute; using %s\n" \
		"${__mantle_xdg_config_default}" >&2
	unset XDG_CONFIG_HOME
fi

if [[ -n "${XDG_CACHE_HOME:-}" && "${XDG_CACHE_HOME}" != /* ]]; then
	printf "[mantle:warn] XDG_CACHE_HOME must be absolute; using %s\n" \
		"${__mantle_xdg_cache_default}" >&2
	unset XDG_CACHE_HOME
fi

if [[ -n "${XDG_DATA_HOME:-}" && "${XDG_DATA_HOME}" != /* ]]; then
	printf "[mantle:warn] XDG_DATA_HOME must be absolute; using %s\n" \
		"${__mantle_xdg_data_default}" >&2
	unset XDG_DATA_HOME
fi

if [[ -n "${XDG_STATE_HOME:-}" && "${XDG_STATE_HOME}" != /* ]]; then
	printf "[mantle:warn] XDG_STATE_HOME must be absolute; using %s\n" \
		"${__mantle_xdg_state_default}" >&2
	unset XDG_STATE_HOME
fi

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${__mantle_xdg_config_default}}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${__mantle_xdg_cache_default}}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${__mantle_xdg_data_default}}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-${__mantle_xdg_state_default}}"
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# XDG_RUNTIME_DIR must be absolute, user-owned, and private. Linux normally
# supplies /run/user/<uid>; macOS and minimal containers need a private fallback.
if [[ -n "${XDG_RUNTIME_DIR:-}" && "${XDG_RUNTIME_DIR}" != /* ]]; then
	printf "[mantle:warn] XDG_RUNTIME_DIR must be absolute; selecting a secure fallback\n" >&2
	unset XDG_RUNTIME_DIR
fi

__mantle_xdg_user_id="$(id -u 2>/dev/null)" || __mantle_xdg_user_id=""

if [[ -z "${__mantle_xdg_user_id}" ]]; then
	printf "[mantle:error] xdg: unable to determine the current user ID\n" >&2
	unset __mantle_xdg_cache_default
	unset __mantle_xdg_config_default
	unset __mantle_xdg_data_default
	unset __mantle_xdg_state_default
	unset __mantle_xdg_user_id
	return 1
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
	if [[ -d "/run/user/${__mantle_xdg_user_id}" &&
		-w "/run/user/${__mantle_xdg_user_id}" &&
		-O "/run/user/${__mantle_xdg_user_id}" ]]; then
		XDG_RUNTIME_DIR="/run/user/${__mantle_xdg_user_id}"
	elif [[ -n "${TMPDIR:-}" && "${TMPDIR}" == /* && -d "${TMPDIR}" ]]; then
		XDG_RUNTIME_DIR="${TMPDIR%/}/mantle-runtime-${__mantle_xdg_user_id}"
	else
		XDG_RUNTIME_DIR="/tmp/mantle-runtime-${__mantle_xdg_user_id}"
	fi

	export XDG_RUNTIME_DIR
fi

if [[ -e "${XDG_RUNTIME_DIR}" && ! -d "${XDG_RUNTIME_DIR}" ]]; then
	printf "[mantle:error] XDG_RUNTIME_DIR exists but is not a directory: %s\n" \
		"${XDG_RUNTIME_DIR}" >&2
	unset __mantle_xdg_cache_default
	unset __mantle_xdg_config_default
	unset __mantle_xdg_data_default
	unset __mantle_xdg_state_default
	unset __mantle_xdg_user_id
	return 1
fi

if [[ ! -d "${XDG_RUNTIME_DIR}" ]]; then
	if ! mkdir -p -- "${XDG_RUNTIME_DIR}" || ! chmod 700 "${XDG_RUNTIME_DIR}"; then
		printf "[mantle:error] unable to create secure XDG runtime directory: %s\n" \
			"${XDG_RUNTIME_DIR}" >&2
		unset __mantle_xdg_cache_default
		unset __mantle_xdg_config_default
		unset __mantle_xdg_data_default
		unset __mantle_xdg_state_default
		unset __mantle_xdg_user_id
		return 1
	fi
elif [[ ! -O "${XDG_RUNTIME_DIR}" ]]; then
	printf "[mantle:error] XDG_RUNTIME_DIR is not owned by the current user: %s\n" \
		"${XDG_RUNTIME_DIR}" >&2
	unset __mantle_xdg_cache_default
	unset __mantle_xdg_config_default
	unset __mantle_xdg_data_default
	unset __mantle_xdg_state_default
	unset __mantle_xdg_user_id
	return 1
elif ! chmod 700 "${XDG_RUNTIME_DIR}"; then
	printf "[mantle:error] unable to secure XDG_RUNTIME_DIR: %s\n" \
		"${XDG_RUNTIME_DIR}" >&2
	unset __mantle_xdg_cache_default
	unset __mantle_xdg_config_default
	unset __mantle_xdg_data_default
	unset __mantle_xdg_state_default
	unset __mantle_xdg_user_id
	return 1
fi

if [[ "${MANTLE_CREATE_XDG_DIRECTORIES:-1}" == "1" ]]; then
	if ! mkdir -p -- \
		"${XDG_CONFIG_HOME}" \
		"${XDG_CACHE_HOME}" \
		"${XDG_DATA_HOME}" \
		"${XDG_STATE_HOME}"; then
		printf "[mantle:error] unable to create one or more XDG base directories\n" >&2
		unset __mantle_xdg_cache_default
		unset __mantle_xdg_config_default
		unset __mantle_xdg_data_default
		unset __mantle_xdg_state_default
		unset __mantle_xdg_user_id
		return 1
	fi
fi

unset __mantle_xdg_cache_default
unset __mantle_xdg_config_default
unset __mantle_xdg_data_default
unset __mantle_xdg_state_default
unset __mantle_xdg_user_id

return 0
