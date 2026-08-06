#!/usr/bin/env bash
# shellcheck shell=bash
# Install image_optim with optional, explicit native dependencies.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

image_optim_version="${IMAGE_OPTIM_VERSION:-}"
image_optim_bindir="${IMAGE_OPTIM_BINDIR:-${XDG_BIN_HOME:-${HOME}/.local/bin}}"
install_system_dependencies="0"
install_svgo="0"
update_package_index="0"
dry_run="0"

# @description Print mantle install image-optim usage.
mantle_install_image_optim_usage() {
	printf "%s\n" \
		"Usage: mantle install image-optim [--version VERSION] [--bindir DIRECTORY]" \
		"                           [--with-system-dependencies] [--with-svgo]" \
		"                           [--update-index] [--dry-run] [--help]" \
		"" \
		"System packages and the global svgo npm package are opt-in side effects."
}

# @description Print a shell-escaped command.
# @arg $@ string Command and arguments.
mantle_install_image_optim_print_command() {
	local argument=""

	printf "+"
	for argument in "$@"; do printf " %q" "${argument}"; done
	printf "\n"
}

while (($# > 0)); do
	case "$1" in
	--version | --gem-version)
		if (($# < 2)) || [[ -z "${2:-}" ]]; then
			mantle_install_image_optim_usage >&2
			exit 64
		fi
		image_optim_version="$2"
		shift 2
		;;
	--bindir)
		if (($# < 2)) || [[ -z "${2:-}" ]]; then
			mantle_install_image_optim_usage >&2
			exit 64
		fi
		image_optim_bindir="$2"
		shift 2
		;;
	--with-system-dependencies)
		install_system_dependencies="1"
		shift
		;;
	--with-svgo)
		install_svgo="1"
		shift
		;;
	--update-index)
		update_package_index="1"
		shift
		;;
	--dry-run)
		dry_run="1"
		shift
		;;
	--help | -h)
		mantle_install_image_optim_usage
		exit 0
		;;
	*)
		mantle_log_error "Unknown argument: $1"
		mantle_install_image_optim_usage >&2
		exit 64
		;;
	esac
done

if [[ "${install_system_dependencies}" == "1" ]]; then
	MANTLE_INSTALL_TOOL_NAME="image-optim-dependencies"
	declare -a MANTLE_INSTALL_PACKAGES_APT=("advancecomp" "gifsicle" "jhead" "jpegoptim" "libjpeg-turbo-progs" "optipng" "pngcrush" "pngquant" "ruby-full")
	declare -a MANTLE_INSTALL_PACKAGES_BREW=("advancecomp" "gifsicle" "jhead" "jpegoptim" "jpeg-turbo" "optipng" "pngcrush" "pngquant" "ruby")
	declare -a MANTLE_INSTALL_PACKAGES_DNF=("advancecomp" "gifsicle" "jhead" "jpegoptim" "libjpeg-turbo-utils" "optipng" "pngcrush" "pngquant" "ruby")
	declare -a MANTLE_INSTALL_PACKAGES_PACMAN=("advancecomp" "gifsicle" "jhead" "jpegoptim" "libjpeg-turbo" "optipng" "pngcrush" "pngquant" "ruby")
	declare -a dependency_arguments=()
	if [[ "${update_package_index}" == "1" ]]; then dependency_arguments+=("--update-index"); fi
	if [[ "${dry_run}" == "1" ]]; then dependency_arguments+=("--dry-run"); fi
	mantle_install_native_package_main "${dependency_arguments[@]}"
fi

if [[ "${dry_run}" == "0" ]] && ! mantle_guard_has_command gem; then
	mantle_log_error "RubyGems is required; install Ruby or use --with-system-dependencies"
	exit 69
fi

declare -a gem_command=(gem install --user-install --no-document --bindir "${image_optim_bindir}")
if [[ -n "${image_optim_version}" ]]; then gem_command+=("--version" "${image_optim_version}"); fi
gem_command+=("image_optim")
if [[ "${dry_run}" == "1" ]]; then
	mantle_install_image_optim_print_command "${gem_command[@]}"
else
	mkdir -p "${image_optim_bindir}"
	"${gem_command[@]}"
fi

if [[ "${install_svgo}" == "1" ]]; then
	if [[ "${dry_run}" == "0" ]] && ! mantle_guard_has_command npm; then
		mantle_log_error "Installing svgo requires npm"
		exit 69
	fi
	if [[ "${dry_run}" == "1" ]]; then
		mantle_install_image_optim_print_command npm install --global svgo
	else
		npm install --global svgo
	fi
fi

if [[ "${dry_run}" == "0" ]]; then
	if [[ ! -x "${image_optim_bindir}/image_optim" ]]; then
		mantle_log_error "image_optim was not installed to ${image_optim_bindir}"
		exit 1
	fi
	mantle_log_success "Installed image_optim to ${image_optim_bindir}/image_optim"
fi
