#!/usr/bin/env bash
# shellcheck shell=bash
#
# Configure XDG-aware locations for developer tools. Existing values always
# win. Stateful tools with legacy data move only through an explicit migration;
# Mantle records them instead of making credentials or installations disappear.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] modules/tooling.sh is internal and must be sourced\n" >&2
	exit 64
elif [[ -n "${ZSH_VERSION:-}" && "${ZSH_EVAL_CONTEXT:-}" != *:file ]]; then
	printf "[mantle:error] modules/tooling.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ -z "${HOME:-}" || -z "${XDG_CONFIG_HOME:-}" ||
	-z "${XDG_DATA_HOME:-}" || -z "${XDG_STATE_HOME:-}" ]]; then
	printf "[mantle:error] tooling: HOME and the XDG config/data/state directories are required\n" >&2
	return 1
fi

__mantle_tooling_variable_is_set() {
	local variable_name="${1:-}"
	local variable_is_set=""

	case "${variable_name}" in
	"" | [!A-Za-z_]* | *[!A-Za-z0-9_]*)
		return 64
		;;
	esac

	eval "variable_is_set=\${${variable_name}+set}"
	[[ "${variable_is_set}" == "set" ]]
}

__mantle_tooling_set_default() {
	local variable_name="${1:-}"
	local variable_value="${2:-}"

	if (($# != 2)); then
		return 64
	fi

	if __mantle_tooling_variable_is_set "${variable_name}"; then
		return 0
	fi

	export "${variable_name}=${variable_value}"
}

__mantle_tooling_set_default_if_file() {
	local variable_name="${1:-}"
	local variable_value="${2:-}"

	if (($# != 2)); then
		return 64
	fi

	if __mantle_tooling_variable_is_set "${variable_name}"; then
		return 0
	fi

	if [[ -f "${variable_value}" ]]; then
		export "${variable_name}=${variable_value}"
	fi
}

__mantle_tooling_record_migration_warning() {
	local variable_name="${1:-}"

	case ":${MANTLE_XDG_MIGRATION_WARNINGS:-}:" in
	*":${variable_name}:"*)
		return 0
		;;
	esac

	if [[ -n "${MANTLE_XDG_MIGRATION_WARNINGS:-}" ]]; then
		MANTLE_XDG_MIGRATION_WARNINGS="${MANTLE_XDG_MIGRATION_WARNINGS}:${variable_name}"
	else
		MANTLE_XDG_MIGRATION_WARNINGS="${variable_name}"
	fi

	export MANTLE_XDG_MIGRATION_WARNINGS

	if [[ "${MANTLE_DEBUG:-0}" == "1" ]]; then
		printf "[mantle:debug] preserving legacy location for %s; an XDG migration is available\n" \
			"${variable_name}" >&2
	fi
}

__mantle_tooling_set_xdg() {
	local variable_name="${1:-}"
	local xdg_path="${2:-}"
	local legacy_path="${3:-}"

	if (($# != 3)); then
		return 64
	fi

	if __mantle_tooling_variable_is_set "${variable_name}"; then
		return 0
	fi

	if [[ -n "${legacy_path}" && -e "${legacy_path}" && ! -e "${xdg_path}" ]]; then
		__mantle_tooling_record_migration_warning "${variable_name}"
		return 0
	fi

	export "${variable_name}=${xdg_path}"
}

__mantle_tooling_configure_rubygems() {
	local gem_home_path="${GEM_HOME:-}"
	local gem_path=""
	local gem_path_entry=""
	local gem_path_seen=0
	local old_ifs="${IFS}"
	local -a gem_path_entries=()
	local -a normalized_gem_path_entries=()

	if ! __mantle_tooling_variable_is_set "GEM_HOME"; then
		export "GEM_HOME=${XDG_DATA_HOME}/gem"
		gem_home_path="${GEM_HOME}"
	fi

	if __mantle_tooling_variable_is_set "GEM_PATH"; then
		return 0
	fi

	if [[ -n "${gem_home_path}" && "${gem_home_path}" != /* ]]; then
		printf "[mantle:warn] GEM_HOME must be absolute for automatic GEM_PATH management; preserving the caller-provided value\n" >&2
		return 0
	fi

	if [[ "${gem_home_path}" != "/" ]]; then
		gem_home_path="${gem_home_path%/}"
	fi

	if ! command -v gem >/dev/null 2>&1; then
		if [[ -n "${ASDF_DATA_DIR:-}" || -n "${RBENV_ROOT:-}" ||
			-n "${MISE_DATA_DIR:-}" || -n "${MISE_INSTALL_PATH:-}" ]]; then
			printf "[mantle:warn] unable to determine GEM_PATH because no active RubyGems command is available; initialize your Ruby manager first or set GEM_PATH explicitly\n" >&2
		fi
		return 0
	fi

	gem_path="$(command gem env path 2>/dev/null)" || gem_path=""
	if [[ -z "${gem_path}" ]]; then
		printf "[mantle:warn] unable to determine GEM_PATH from the active RubyGems; leaving GEM_PATH unset\n" >&2
		return 0
	fi

	IFS=: read -r -a gem_path_entries <<< "${gem_path}"
	for gem_path_entry in "${gem_path_entries[@]}"; do
		if [[ "${gem_path_entry}" != "/" ]]; then
			gem_path_entry="${gem_path_entry%/}"
		fi
		normalized_gem_path_entries+=("${gem_path_entry}")
		if [[ "${gem_path_entry}" == "${gem_home_path}" ]]; then
			gem_path_seen=1
		fi
	done

	if ((gem_path_seen == 0)); then
		normalized_gem_path_entries+=("${gem_home_path}")
	fi

	IFS=:
	gem_path="${normalized_gem_path_entries[*]}"
	IFS="${old_ifs}"

	export "GEM_PATH=${gem_path}"
}

# Version managers and language runtimes.
__mantle_tooling_set_xdg "ASDF_DATA_DIR" "${XDG_DATA_HOME}/asdf" "${HOME}/.asdf"
__mantle_tooling_set_xdg "PYENV_ROOT" "${XDG_DATA_HOME}/pyenv" "${HOME}/.pyenv"
__mantle_tooling_set_xdg "RBENV_ROOT" "${XDG_DATA_HOME}/rbenv" "${HOME}/.rbenv"
__mantle_tooling_set_xdg "NVM_DIR" "${XDG_DATA_HOME}/nvm" "${HOME}/.nvm"
__mantle_tooling_set_xdg "VOLTA_HOME" "${XDG_DATA_HOME}/volta" "${HOME}/.volta"
__mantle_tooling_set_default "PNPM_HOME" "${XDG_DATA_HOME}/pnpm"
__mantle_tooling_set_xdg "CARGO_HOME" "${XDG_DATA_HOME}/cargo" "${HOME}/.cargo"
__mantle_tooling_set_xdg "RUSTUP_HOME" "${XDG_DATA_HOME}/rustup" "${HOME}/.rustup"
__mantle_tooling_set_default "GOPATH" "${XDG_DATA_HOME}/go"
__mantle_tooling_set_xdg "SDKMAN_DIR" "${XDG_DATA_HOME}/sdkman" "${HOME}/.sdkman"
__mantle_tooling_set_default "GHCUP_USE_XDG_DIRS" "true"
__mantle_tooling_set_default "STACK_ROOT" "${XDG_DATA_HOME}/stack"
__mantle_tooling_set_default "CABAL_DIR" "${XDG_DATA_HOME}/cabal"
__mantle_tooling_set_default "OPAMROOT" "${XDG_DATA_HOME}/opam"
__mantle_tooling_set_default "DUB_HOME" "${XDG_DATA_HOME}/dub"
__mantle_tooling_set_default "ELM_HOME" "${XDG_DATA_HOME}/elm"

# Python, Ruby, Java, and .NET.
__mantle_tooling_set_default_if_file "PIP_CONFIG_FILE" "${XDG_CONFIG_HOME}/pip/pip.conf"
__mantle_tooling_set_default "PIPX_HOME" "${XDG_DATA_HOME}/pipx"
__mantle_tooling_set_default "PIPX_BIN_DIR" "${XDG_DATA_HOME}/pipx/bin"
__mantle_tooling_set_default "POETRY_HOME" "${XDG_DATA_HOME}/poetry"
__mantle_tooling_set_default "IPYTHONDIR" "${XDG_CONFIG_HOME}/ipython"
__mantle_tooling_set_default "JUPYTER_CONFIG_DIR" "${XDG_CONFIG_HOME}/jupyter"
__mantle_tooling_set_default_if_file "PYTHONSTARTUP" "${XDG_CONFIG_HOME}/python/pythonrc"
__mantle_tooling_configure_rubygems
__mantle_tooling_set_default "BUNDLE_USER_CONFIG" "${XDG_CONFIG_HOME}/bundle"
__mantle_tooling_set_default "BUNDLE_USER_PLUGIN" "${XDG_DATA_HOME}/bundle"
__mantle_tooling_set_default "GRADLE_USER_HOME" "${XDG_DATA_HOME}/gradle"
__mantle_tooling_set_default "MAVEN_USER_HOME" "${XDG_DATA_HOME}/maven"
__mantle_tooling_set_default "DOTNET_CLI_HOME" "${XDG_DATA_HOME}/dotnet"

# JavaScript and web tooling.
__mantle_tooling_set_default_if_file "NPM_CONFIG_USERCONFIG" "${XDG_CONFIG_HOME}/npm/npmrc"
__mantle_tooling_set_default "YARN_GLOBAL_FOLDER" "${XDG_DATA_HOME}/yarn"
__mantle_tooling_set_default "BUN_INSTALL" "${XDG_DATA_HOME}/bun"

# Cloud, infrastructure, and container tooling.
__mantle_tooling_set_xdg "DOCKER_CONFIG" "${XDG_CONFIG_HOME}/docker" "${HOME}/.docker"
__mantle_tooling_set_xdg "GNUPGHOME" "${XDG_DATA_HOME}/gnupg" "${HOME}/.gnupg"
__mantle_tooling_set_xdg "AWS_CONFIG_FILE" "${XDG_CONFIG_HOME}/aws/config" "${HOME}/.aws/config"
__mantle_tooling_set_xdg "AWS_SHARED_CREDENTIALS_FILE" "${XDG_CONFIG_HOME}/aws/credentials" "${HOME}/.aws/credentials"
__mantle_tooling_set_default "AZURE_CONFIG_DIR" "${XDG_DATA_HOME}/azure"
__mantle_tooling_set_default "CLOUDSDK_CONFIG" "${XDG_CONFIG_HOME}/gcloud"
__mantle_tooling_set_default "K9SCONFIG" "${XDG_CONFIG_HOME}/k9s"
__mantle_tooling_set_default "MINIKUBE_HOME" "${XDG_DATA_HOME}/minikube"
__mantle_tooling_set_default "VAGRANT_HOME" "${XDG_DATA_HOME}/vagrant"
__mantle_tooling_set_default "ANSIBLE_HOME" "${XDG_DATA_HOME}/ansible"
__mantle_tooling_set_default_if_file "ANSIBLE_CONFIG" "${XDG_CONFIG_HOME}/ansible/ansible.cfg"
__mantle_tooling_set_default "PULUMI_HOME" "${XDG_DATA_HOME}/pulumi"

# Shell, terminal, and editor tooling. Paths that identify a concrete config
# file are exported only after that file exists, preventing tool startup errors.
__mantle_tooling_set_default_if_file "STARSHIP_CONFIG" "${XDG_CONFIG_HOME}/starship.toml"
__mantle_tooling_set_default_if_file "RIPGREP_CONFIG_PATH" "${XDG_CONFIG_HOME}/ripgrep/config"
__mantle_tooling_set_default_if_file "INPUTRC" "${XDG_CONFIG_HOME}/readline/inputrc"
__mantle_tooling_set_default_if_file "SCREENRC" "${XDG_CONFIG_HOME}/screen/screenrc"
__mantle_tooling_set_default_if_file "WGETRC" "${XDG_CONFIG_HOME}/wget/wgetrc"
__mantle_tooling_set_default "CURL_HOME" "${XDG_CONFIG_HOME}/curl"
__mantle_tooling_set_default "_Z_DATA" "${XDG_DATA_HOME}/z/data"
__mantle_tooling_set_default "WAKATIME_HOME" "${XDG_CONFIG_HOME}/wakatime"

# Databases and data tooling.
__mantle_tooling_set_default_if_file "PSQLRC" "${XDG_CONFIG_HOME}/postgresql/psqlrc"
__mantle_tooling_set_default_if_file "PGPASSFILE" "${XDG_CONFIG_HOME}/postgresql/pgpass"
__mantle_tooling_set_default_if_file "PGSERVICEFILE" "${XDG_CONFIG_HOME}/postgresql/pg_service.conf"
__mantle_tooling_set_default_if_file "REDISCLI_RCFILE" "${XDG_CONFIG_HOME}/redis/redisclirc"
__mantle_tooling_set_default "IPFS_PATH" "${XDG_DATA_HOME}/ipfs"
__mantle_tooling_set_default "PLATFORMIO_CORE_DIR" "${XDG_DATA_HOME}/platformio"
__mantle_tooling_set_default "JULIA_DEPOT_PATH" "${XDG_DATA_HOME}/julia"

# Media and creative tooling.
__mantle_tooling_set_default "CALIBRE_CONFIG_DIRECTORY" "${XDG_CONFIG_HOME}/calibre"
__mantle_tooling_set_xdg "WINEPREFIX" "${XDG_DATA_HOME}/wine" "${HOME}/.wine"
__mantle_tooling_set_default "HOUDINI_USER_PREF_DIR" "${XDG_DATA_HOME}/houdini__HVER__"

# Android, Dart, and Flutter.
__mantle_tooling_set_xdg "ANDROID_USER_HOME" "${XDG_DATA_HOME}/android" "${HOME}/.android"
__mantle_tooling_set_default "ANDROID_HOME" "${XDG_DATA_HOME}/android/sdk"
__mantle_tooling_set_default "ANDROID_SDK_ROOT" "${ANDROID_HOME:-${XDG_DATA_HOME}/android/sdk}"
__mantle_tooling_set_default "ANDROID_AVD_HOME" "${XDG_DATA_HOME}/android/avd"
__mantle_tooling_set_default "ANALYZER_STATE_LOCATION_OVERRIDE" "${XDG_STATE_HOME}/dart/analysis-server"
__mantle_tooling_set_default "FLUTTER_HOME" "${XDG_DATA_HOME}/flutter"

unset -f __mantle_tooling_record_migration_warning
unset -f __mantle_tooling_configure_rubygems
unset -f __mantle_tooling_set_default
unset -f __mantle_tooling_set_default_if_file
unset -f __mantle_tooling_set_xdg
unset -f __mantle_tooling_variable_is_set

return 0
