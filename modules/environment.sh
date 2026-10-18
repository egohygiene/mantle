#!/usr/bin/env bash
# shellcheck shell=bash
#
# Configure Mantle's portable locale, editor, executable-path, and language
# runtime defaults. Existing user-selected values take precedence.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/environment.sh is internal and must be sourced\n" >&2
	exit 64
elif [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] modules/environment.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ -z "${MANTLE_ROOT:-}" || "${MANTLE_ROOT}" != /* ]]; then
	printf "[mantle:error] environment: MANTLE_ROOT must be an absolute path\n" >&2
	return 1
fi

if [[ -z "${HOME:-}" || -z "${XDG_DATA_HOME:-}" || -z "${XDG_CONFIG_HOME:-}" ]]; then
	printf "[mantle:error] environment: HOME and the XDG data/config directories are required\n" >&2
	return 1
fi

if ! command -v mantle_core_path_prepend >/dev/null 2>&1; then
	printf "[mantle:error] environment: core PATH ownership is unavailable\n" >&2
	return 1
fi

# Do not set LC_ALL: it overrides every locale category and prevents callers
# from selecting category-specific behavior. LANG supplies the portable default.
export LANG="${LANG:-en_US.UTF-8}"

if [[ -z "${EDITOR:-}" ]]; then
	if command -v nvim >/dev/null 2>&1; then
		EDITOR="nvim"
	elif command -v vim >/dev/null 2>&1; then
		EDITOR="vim"
	else
		EDITOR="vi"
	fi

	export EDITOR
fi

export VISUAL="${VISUAL:-${EDITOR}}"

export PATH="${PATH:-/usr/bin:/bin}"
export XDG_BIN_HOME="${XDG_BIN_HOME:-${HOME}/.local/bin}"

if [[ "${XDG_BIN_HOME}" != /* ]]; then
	printf "[mantle:error] environment: XDG_BIN_HOME must be an absolute path\n" >&2
	return 1
fi

if [[ "${MANTLE_CREATE_XDG_DIRECTORIES:-1}" == "1" ]] &&
	! mkdir -p -- "${XDG_BIN_HOME}"; then
	printf "[mantle:error] environment: unable to create XDG_BIN_HOME: %s\n" \
		"${XDG_BIN_HOME}" >&2
	return 1
fi

# Minimal profiles retain the public command surface and caller-owned user bin.
# Developer projections and tool-specific defaults belong to the tooling profile.
if command -v mantle_profile_has >/dev/null 2>&1 && ! mantle_profile_has "tooling"; then
	for __mantle_environment_path_candidate in "${XDG_BIN_HOME}" "${MANTLE_ROOT}/bin"; do
		if [[ -d "${__mantle_environment_path_candidate}" ]]; then
			mantle_core_path_prepend "${__mantle_environment_path_candidate}" || {
				unset __mantle_environment_path_candidate
				return 1
			}
		fi
	done
	unset __mantle_environment_path_candidate
	return 0
fi

__mantle_environment_gem_home_path="${GEM_HOME:-${XDG_DATA_HOME}/gem}"

# Candidates are ordered from lowest to highest priority because each existing
# directory is prepended. Mantle commands remain the highest-priority managed
# command surface; a caller's pre-existing PATH entries retain their order.
__mantle_environment_asdf_root="${ASDF_DATA_DIR:-${XDG_DATA_HOME}/asdf}"
__mantle_environment_pyenv_root="${PYENV_ROOT:-${XDG_DATA_HOME}/pyenv}"
__mantle_environment_volta_root="${VOLTA_HOME:-${XDG_DATA_HOME}/volta}"
__mantle_environment_go_root="${GOPATH:-${XDG_DATA_HOME}/go}"
__mantle_environment_cargo_root="${CARGO_HOME:-${XDG_DATA_HOME}/cargo}"

if [[ -z "${ASDF_DATA_DIR:-}" && -d "${HOME}/.asdf" &&
	! -e "${XDG_DATA_HOME}/asdf" ]]; then
	__mantle_environment_asdf_root="${HOME}/.asdf"
fi
if [[ -z "${PYENV_ROOT:-}" && -d "${HOME}/.pyenv" &&
	! -e "${XDG_DATA_HOME}/pyenv" ]]; then
	__mantle_environment_pyenv_root="${HOME}/.pyenv"
fi
if [[ -z "${VOLTA_HOME:-}" && -d "${HOME}/.volta" &&
	! -e "${XDG_DATA_HOME}/volta" ]]; then
	__mantle_environment_volta_root="${HOME}/.volta"
fi
if [[ -z "${GOPATH:-}" && -d "${HOME}/go" &&
	! -e "${XDG_DATA_HOME}/go" ]]; then
	__mantle_environment_go_root="${HOME}/go"
fi
if [[ -z "${CARGO_HOME:-}" && -d "${HOME}/.cargo" &&
	! -e "${XDG_DATA_HOME}/cargo" ]]; then
	__mantle_environment_cargo_root="${HOME}/.cargo"
fi

__mantle_environment_path_candidates=(
	"${__mantle_environment_asdf_root}/bin"
	"${__mantle_environment_asdf_root}/shims"
	"${__mantle_environment_pyenv_root}/bin"
	"${__mantle_environment_volta_root}/bin"
	"${PIPX_BIN_DIR:-${XDG_DATA_HOME}/pipx/bin}"
	"${__mantle_environment_go_root}/bin"
	"${__mantle_environment_cargo_root}/bin"
	"${PNPM_HOME:-${XDG_DATA_HOME}/pnpm}"
	"${XDG_BIN_HOME}"
	"${MANTLE_ROOT}/bin"
)

if [[ -n "${__mantle_environment_gem_home_path}" &&
	"${__mantle_environment_gem_home_path}" == /* ]]; then
	while [[ "${__mantle_environment_gem_home_path}" != "/" &&
		"${__mantle_environment_gem_home_path}" == */ ]]; do
		__mantle_environment_gem_home_path="${__mantle_environment_gem_home_path%/}"
	done
	# RubyGems may create this directory during the current shell session. Keep
	# this one planned path discoverable before its first gem installation.
	__mantle_environment_gem_bin="${__mantle_environment_gem_home_path}/bin"
	if mantle_core_path_contains "${__mantle_environment_gem_bin}"; then
		:
	elif [[ "$?" == "1" ]]; then
		PATH="${__mantle_environment_gem_bin}${PATH:+:${PATH}}"
		export PATH
	else
		printf "[mantle:error] environment: invalid RubyGems PATH candidate\n" >&2
		unset __mantle_environment_gem_bin __mantle_environment_gem_home_path
		unset __mantle_environment_path_candidates
		return 1
	fi
	unset __mantle_environment_gem_bin
elif [[ -n "${__mantle_environment_gem_home_path}" ]]; then
	printf "[mantle:warn] GEM_HOME must be absolute for automatic PATH management; preserving the caller-provided value\n" >&2
fi

for __mantle_environment_path_candidate in "${__mantle_environment_path_candidates[@]}"; do
	if [[ -d "${__mantle_environment_path_candidate}" ]]; then
		mantle_core_path_prepend \
			"${__mantle_environment_path_candidate}" || {
			printf "[mantle:error] environment: invalid PATH candidate: %s\n" \
				"${__mantle_environment_path_candidate}" >&2
			unset __mantle_environment_path_candidate
			unset __mantle_environment_path_candidates
			return 1
		}
	fi
done

# Project-local executable directories are intentionally opt-in. Capturing the
# startup working directory in PATH can become stale after cd and can make an
# untrusted executable available merely because the shell started in a project.
if [[ "${MANTLE_ENABLE_PROJECT_PATH:-0}" == "1" ]]; then
	for __mantle_environment_project_path in "${PWD}/bin" "${PWD}/node_modules/.bin"; do
		if [[ -d "${__mantle_environment_project_path}" ]]; then
			mantle_core_path_prepend \
				"${__mantle_environment_project_path}" || {
				printf "[mantle:error] environment: invalid project PATH candidate: %s\n" \
					"${__mantle_environment_project_path}" >&2
				unset __mantle_environment_path_candidate
				unset __mantle_environment_path_candidates
				unset __mantle_environment_project_path
				return 1
			}
		fi
	done
	unset __mantle_environment_project_path
fi

export CLICOLOR="${CLICOLOR:-1}"
export PYTHONUTF8="${PYTHONUTF8:-1}"
export PYTHONIOENCODING="${PYTHONIOENCODING:-UTF-8}"
export PIPENV_VENV_IN_PROJECT="${PIPENV_VENV_IN_PROJECT:-1}"
export POETRY_PREVIEW="${POETRY_PREVIEW:-1}"
export GCC_COLORS="${GCC_COLORS:-error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01}"
export GHCUP_USE_XDG_DIRS="${GHCUP_USE_XDG_DIRS:-true}"

unset __mantle_environment_path_candidate
unset __mantle_environment_path_candidates
unset __mantle_environment_gem_home_path
unset __mantle_environment_asdf_root __mantle_environment_pyenv_root
unset __mantle_environment_volta_root __mantle_environment_go_root __mantle_environment_cargo_root

return 0
