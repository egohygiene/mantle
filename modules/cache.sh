#!/usr/bin/env bash
# shellcheck shell=bash
#
# Redirect supported tool caches, temporary data, and logs into Mantle's XDG
# directory contract. Existing user-selected values take precedence.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/cache.sh is internal and must be sourced\n" >&2
	exit 64
elif [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] modules/cache.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ -z "${XDG_CACHE_HOME:-}" || -z "${XDG_STATE_HOME:-}" ||
	-z "${XDG_RUNTIME_DIR:-}" ]]; then
	printf "[mantle:error] cache: XDG cache, state, and runtime directories are required\n" >&2
	return 1
fi

__mantle_cache_set_default() {
	local variable_name="${1:-}"
	local variable_value="${2:-}"
	local variable_is_set=""

	if (($# != 2)); then
		return 64
	fi

	case "${variable_name}" in
	"" | [!A-Za-z_]* | *[!A-Za-z0-9_]*)
		return 64
		;;
	esac

	eval "variable_is_set=\${${variable_name}+set}"
	if [[ "${variable_is_set}" != "set" ]]; then
		export "${variable_name}=${variable_value}"
	fi
}

# Development languages and build systems.
__mantle_cache_set_default "SONARLINT_USER_HOME" "${XDG_CACHE_HOME}/sonarlint"
__mantle_cache_set_default "NODE_COMPILER_CACHE" "${XDG_CACHE_HOME}/node/compiler"
__mantle_cache_set_default "YARN_CACHE_FOLDER" "${XDG_CACHE_HOME}/yarn"
__mantle_cache_set_default "PUB_CACHE" "${XDG_CACHE_HOME}/dart-pub"
__mantle_cache_set_default "KSCRIPT_CACHE_DIR" "${XDG_CACHE_HOME}/kscript"
__mantle_cache_set_default "EM_CACHE" "${XDG_CACHE_HOME}/emscripten"
__mantle_cache_set_default "BUNDLE_USER_CACHE" "${XDG_CACHE_HOME}/bundle"
__mantle_cache_set_default "GEM_SPEC_CACHE" "${XDG_CACHE_HOME}/gem/specs"
__mantle_cache_set_default "NUGET_PACKAGES" "${XDG_CACHE_HOME}/nuget/packages"
__mantle_cache_set_default "DENO_DIR" "${XDG_CACHE_HOME}/deno"
__mantle_cache_set_default "UV_CACHE_DIR" "${XDG_CACHE_HOME}/uv"
__mantle_cache_set_default "PIP_CACHE_DIR" "${XDG_CACHE_HOME}/pip"
__mantle_cache_set_default "GOMODCACHE" "${XDG_CACHE_HOME}/go/mod"
__mantle_cache_set_default "TERRAGRUNT_DOWNLOAD" "${XDG_CACHE_HOME}/terragrunt"
__mantle_cache_set_default "TF_PLUGIN_CACHE_DIR" "${XDG_CACHE_HOME}/terraform/plugin-cache"
__mantle_cache_set_default "KUBECACHEDIR" "${XDG_CACHE_HOME}/kubernetes"

# Python and language-analysis tools.
__mantle_cache_set_default "PYTHON_EGG_CACHE" "${XDG_CACHE_HOME}/python-eggs"
__mantle_cache_set_default "PEX_ROOT" "${XDG_CACHE_HOME}/pex"
__mantle_cache_set_default "MYPY_CACHE_DIR" "${XDG_CACHE_HOME}/mypy"
__mantle_cache_set_default "PYLINTHOME" "${XDG_CACHE_HOME}/pylint"
__mantle_cache_set_default "RUFF_CACHE_DIR" "${XDG_CACHE_HOME}/ruff"
__mantle_cache_set_default "SOLARGRAPH_CACHE" "${XDG_CACHE_HOME}/solargraph"

# Hardware and graphics.
__mantle_cache_set_default "__GL_SHADER_DISK_CACHE_PATH" "${XDG_CACHE_HOME}/nvidia"
__mantle_cache_set_default "CUDA_CACHE_PATH" "${XDG_CACHE_HOME}/nvidia"
__mantle_cache_set_default "XCOMPOSECACHE" "${XDG_CACHE_HOME}/x11/xcompose"

# Shell and interface tools.
__mantle_cache_set_default "STARSHIP_CACHE" "${XDG_CACHE_HOME}/starship"
__mantle_cache_set_default "XMONAD_CACHE_DIR" "${XDG_CACHE_HOME}/xmonad"

# Package managers and creative tooling.
__mantle_cache_set_default "HOMEBREW_CACHE" "${XDG_CACHE_HOME}/homebrew"
__mantle_cache_set_default "HOMEBREW_TEMP" "${XDG_RUNTIME_DIR}/homebrew"
__mantle_cache_set_default "HOMEBREW_LOGS" "${XDG_STATE_HOME}/homebrew/logs"
__mantle_cache_set_default "CALIBRE_CACHE_DIRECTORY" "${XDG_CACHE_HOME}/calibre"
__mantle_cache_set_default "CALIBRE_TEMP_DIR" "${XDG_RUNTIME_DIR}/calibre"
__mantle_cache_set_default "DVDCSS_CACHE" "${XDG_CACHE_HOME}/dvdcss"
__mantle_cache_set_default "SINGULARITY_CACHEDIR" "${XDG_CACHE_HOME}/singularity"

unset -f __mantle_cache_set_default

return 0
