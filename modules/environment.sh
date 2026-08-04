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

__mantle_environment_path_prepend() {
	local path_candidate="${1:-}"

	if [[ -z "${path_candidate}" || "${path_candidate}" == *:* ]]; then
		return 64
	fi

	case ":${PATH:-}:" in
	*":${path_candidate}:"*)
		return 0
		;;
	esac

	if [[ -n "${PATH:-}" ]]; then
		PATH="${path_candidate}:${PATH}"
	else
		PATH="${path_candidate}"
	fi

	export PATH
}

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
	unset -f __mantle_environment_path_prepend
	return 1
fi

if [[ "${MANTLE_CREATE_XDG_DIRECTORIES:-1}" == "1" ]] &&
	! mkdir -p -- "${XDG_BIN_HOME}"; then
	printf "[mantle:error] environment: unable to create XDG_BIN_HOME: %s\n" \
		"${XDG_BIN_HOME}" >&2
	unset -f __mantle_environment_path_prepend
	return 1
fi

# Candidates are ordered from lowest to highest priority because each existing
# directory is prepended. Mantle commands remain the highest-priority managed
# command surface; a caller's pre-existing PATH entries retain their order.
__mantle_environment_path_candidates=(
	"${ASDF_DATA_DIR:-${XDG_DATA_HOME}/asdf}/bin"
	"${ASDF_DATA_DIR:-${XDG_DATA_HOME}/asdf}/shims"
	"${PYENV_ROOT:-${XDG_DATA_HOME}/pyenv}/bin"
	"${VOLTA_HOME:-${XDG_DATA_HOME}/volta}/bin"
	"${PIPX_BIN_DIR:-${XDG_DATA_HOME}/pipx/bin}"
	"${GOPATH:-${XDG_DATA_HOME}/go}/bin"
	"${CARGO_HOME:-${XDG_DATA_HOME}/cargo}/bin"
	"${PNPM_HOME:-${XDG_DATA_HOME}/pnpm}"
	"${XDG_BIN_HOME}"
	"${MANTLE_ROOT}/bin"
)

for __mantle_environment_path_candidate in "${__mantle_environment_path_candidates[@]}"; do
	if [[ -d "${__mantle_environment_path_candidate}" ]]; then
		__mantle_environment_path_prepend \
			"${__mantle_environment_path_candidate}" || {
			printf "[mantle:error] environment: invalid PATH candidate: %s\n" \
				"${__mantle_environment_path_candidate}" >&2
			unset -f __mantle_environment_path_prepend
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
			__mantle_environment_path_prepend \
				"${__mantle_environment_project_path}" || {
				printf "[mantle:error] environment: invalid project PATH candidate: %s\n" \
					"${__mantle_environment_project_path}" >&2
				unset -f __mantle_environment_path_prepend
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

unset -f __mantle_environment_path_prepend
unset __mantle_environment_path_candidate
unset __mantle_environment_path_candidates

return 0
