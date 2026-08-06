#!/usr/bin/env bash
# shellcheck shell=bash
# Install or update pyenv and its maintained companion plugins.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

pyenv_target="${PYENV_ROOT:-${XDG_DATA_HOME:-${HOME}/.local/share}/pyenv}"
pyenv_ref="${PYENV_GIT_TAG:-master}"
python_version=""
update_existing="0"
install_plugins="1"
dry_run="0"
temporary_directory=""
declare -a plugin_names=("pyenv-doctor" "pyenv-update" "pyenv-virtualenv")

# @description Print mantle install pyenv usage.
mantle_install_pyenv_usage() {
	printf "%s\n" \
		"Usage: mantle install pyenv [--target DIRECTORY] [--ref REF] [--python VERSION] [--update] [--no-plugins] [--dry-run] [--help]" \
		"" \
		"Installs pyenv into an XDG data directory. Existing checkouts are never changed" \
		"unless --update is explicit. Updates refuse dirty working trees."
}

# @description Print a shell-escaped command.
# @arg $@ string Command and arguments.
mantle_install_pyenv_print_command() {
	local argument=""

	printf "+"
	for argument in "$@"; do
		printf " %q" "${argument}"
	done
	printf "\n"
}

# @description Run a command, or only print it during a dry run.
# @arg $@ string Command and arguments.
mantle_install_pyenv_run() {
	mantle_install_pyenv_print_command "$@"
	if [[ "${dry_run}" == "0" ]]; then
		"$@"
	fi
}

# @description Refuse to update a Git checkout containing local changes.
# @arg $1 string Git checkout directory.
mantle_install_pyenv_assert_clean_checkout() {
	local checkout_directory="${1:-}"

	if (($# != 1)) || [[ ! -d "${checkout_directory}/.git" ]]; then
		return 64
	fi
	if ! git -C "${checkout_directory}" diff --quiet --ignore-submodules -- ||
		! git -C "${checkout_directory}" diff --cached --quiet --ignore-submodules --; then
		mantle_log_error "Refusing to update a checkout with local changes: ${checkout_directory}"
		return 73
	fi
}

# @description Check out one remote Git ref without evaluating repository content.
# @arg $1 string Git checkout directory.
# @arg $2 string Git ref.
mantle_install_pyenv_checkout_ref() {
	local checkout_directory="${1:-}"
	local requested_ref="${2:-}"

	if (($# != 2)) || [[ -z "${checkout_directory}" || -z "${requested_ref}" ]]; then
		return 64
	fi
	mantle_install_pyenv_run git -C "${checkout_directory}" fetch --depth 1 origin "${requested_ref}"
	mantle_install_pyenv_run git -C "${checkout_directory}" checkout --detach FETCH_HEAD
}

# @description Clone or update one pyenv plugin.
# @arg $1 string pyenv root directory.
# @arg $2 string Plugin repository name.
mantle_install_pyenv_install_plugin() {
	local root_directory="${1:-}"
	local plugin_name="${2:-}"
	local plugin_directory="${root_directory}/plugins/${plugin_name}"
	local repository_url="https://github.com/pyenv/${plugin_name}.git"

	if (($# != 2)); then
		return 64
	fi
	if [[ -d "${plugin_directory}/.git" ]]; then
		if [[ "${update_existing}" == "1" ]]; then
			mantle_install_pyenv_assert_clean_checkout "${plugin_directory}" || return $?
			mantle_install_pyenv_checkout_ref "${plugin_directory}" "HEAD" || return $?
		fi
		return 0
	fi
	if [[ -e "${plugin_directory}" ]]; then
		mantle_log_error "Plugin target exists but is not a Git checkout: ${plugin_directory}"
		return 73
	fi
	mantle_install_pyenv_run git clone --filter=blob:none --depth 1 "${repository_url}" "${plugin_directory}"
}

# @description Remove the staging directory created by this installer.
mantle_install_pyenv_cleanup() {
	if [[ -n "${temporary_directory}" && -d "${temporary_directory}" &&
		"${temporary_directory##*/}" == .mantle-pyenv.* ]]; then
		rm -R -- "${temporary_directory}"
	fi
}

while (($# > 0)); do
	case "$1" in
	--target)
		if (($# < 2)) || [[ -z "${2:-}" ]]; then
			mantle_install_pyenv_usage >&2
			exit 64
		fi
		pyenv_target="$2"
		shift 2
		;;
	--ref)
		if (($# < 2)) || [[ -z "${2:-}" ]]; then
			mantle_install_pyenv_usage >&2
			exit 64
		fi
		pyenv_ref="$2"
		shift 2
		;;
	--python)
		if (($# < 2)) || [[ -z "${2:-}" ]]; then
			mantle_install_pyenv_usage >&2
			exit 64
		fi
		python_version="$2"
		shift 2
		;;
	--update)
		update_existing="1"
		shift
		;;
	--no-plugins)
		install_plugins="0"
		shift
		;;
	--dry-run)
		dry_run="1"
		shift
		;;
	--help | -h)
		mantle_install_pyenv_usage
		exit 0
		;;
	*)
		mantle_log_error "Unknown argument: $1"
		mantle_install_pyenv_usage >&2
		exit 64
		;;
	esac
done

if ! mantle_guard_has_command git; then
	mantle_log_error "Installing pyenv requires git"
	exit 69
fi

if [[ -d "${pyenv_target}/.git" ]]; then
	if [[ "${update_existing}" == "1" ]]; then
		mantle_install_pyenv_assert_clean_checkout "${pyenv_target}"
		mantle_install_pyenv_checkout_ref "${pyenv_target}" "${pyenv_ref}"
	else
		mantle_log_success "pyenv is already installed at ${pyenv_target}"
	fi
elif [[ -e "${pyenv_target}" ]]; then
	mantle_log_error "Target exists but is not a pyenv checkout: ${pyenv_target}"
	exit 73
else
	pyenv_parent="$(dirname "${pyenv_target}")"
	mantle_install_pyenv_run mkdir -p "${pyenv_parent}"
	if [[ "${dry_run}" == "1" ]]; then
		temporary_directory="${pyenv_parent}/.mantle-pyenv.DRY_RUN"
	else
		temporary_directory="$(mktemp -d "${pyenv_parent}/.mantle-pyenv.XXXXXX")"
		trap mantle_install_pyenv_cleanup EXIT
	fi
	mantle_install_pyenv_run git clone --filter=blob:none --no-checkout "https://github.com/pyenv/pyenv.git" "${temporary_directory}/pyenv"
	mantle_install_pyenv_checkout_ref "${temporary_directory}/pyenv" "${pyenv_ref}"
	mantle_install_pyenv_run mv "${temporary_directory}/pyenv" "${pyenv_target}"
fi

if [[ "${install_plugins}" == "1" ]]; then
	for plugin_name in "${plugin_names[@]}"; do
		mantle_install_pyenv_install_plugin "${pyenv_target}" "${plugin_name}"
	done
fi

if [[ -n "${python_version}" ]]; then
	mantle_install_pyenv_run env PYENV_ROOT="${pyenv_target}" "${pyenv_target}/bin/pyenv" install --skip-existing "${python_version}"
	mantle_install_pyenv_run env PYENV_ROOT="${pyenv_target}" "${pyenv_target}/bin/pyenv" global "${python_version}"
	mantle_install_pyenv_run env PYENV_ROOT="${pyenv_target}" "${pyenv_target}/bin/pyenv" rehash
fi

printf "pyenv root: %s\n" "${pyenv_target}"
printf "Reload your shell after Mantle adds pyenv to PATH.\n"
