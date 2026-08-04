#!/usr/bin/env bash
# shellcheck shell=bash
# Install ImageMagick through the host's native package manager.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="imagemagick"
declare -a MANTLE_INSTALL_PACKAGES_APK=("imagemagick")
declare -a MANTLE_INSTALL_PACKAGES_APT=("imagemagick")
declare -a MANTLE_INSTALL_PACKAGES_BREW=("imagemagick")
declare -a MANTLE_INSTALL_PACKAGES_DNF=("ImageMagick")
declare -a MANTLE_INSTALL_PACKAGES_PACMAN=("imagemagick")
declare -a MANTLE_INSTALL_PACKAGES_YUM=("ImageMagick")
declare -a MANTLE_INSTALL_PACKAGES_ZYPPER=("ImageMagick")
declare -a MANTLE_INSTALL_NATIVE_VERIFY_COMMANDS=("magick")

mantle_install_native_package_main "$@"
