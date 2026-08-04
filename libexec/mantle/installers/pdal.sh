#!/usr/bin/env bash
# shellcheck shell=bash
# Install PDAL and its development files with the native package manager.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="pdal"
declare -a MANTLE_INSTALL_PACKAGES_APT=("pdal" "libpdal-dev")
declare -a MANTLE_INSTALL_PACKAGES_BREW=("pdal")
declare -a MANTLE_INSTALL_PACKAGES_DNF=("pdal" "pdal-devel")
declare -a MANTLE_INSTALL_PACKAGES_PACMAN=("pdal")
declare -a MANTLE_INSTALL_PACKAGES_ZYPPER=("pdal" "pdal-devel")
declare -a MANTLE_INSTALL_NATIVE_VERIFY_COMMANDS=("pdal")

mantle_install_native_package_main "$@"
