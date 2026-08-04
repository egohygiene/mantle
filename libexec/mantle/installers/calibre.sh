#!/usr/bin/env bash
# shellcheck shell=bash
# Install Calibre through the host's native package manager.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="calibre"
declare -a MANTLE_INSTALL_PACKAGES_APT=("calibre")
declare -a MANTLE_INSTALL_PACKAGES_BREW_CASK=("calibre")
declare -a MANTLE_INSTALL_PACKAGES_DNF=("calibre")
declare -a MANTLE_INSTALL_PACKAGES_PACMAN=("calibre")
declare -a MANTLE_INSTALL_PACKAGES_ZYPPER=("calibre")
declare -a MANTLE_INSTALL_NATIVE_VERIFY_COMMANDS=("calibredb" "ebook-convert")

mantle_install_native_package_main "$@"
