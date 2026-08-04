#!/usr/bin/env bash
# shellcheck shell=bash
# Install Lynis through the host's native package manager.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="lynis"
declare -a MANTLE_INSTALL_PACKAGES_APT=("lynis")
declare -a MANTLE_INSTALL_PACKAGES_BREW=("lynis")
declare -a MANTLE_INSTALL_PACKAGES_DNF=("lynis")
declare -a MANTLE_INSTALL_PACKAGES_PACMAN=("lynis")
declare -a MANTLE_INSTALL_PACKAGES_YUM=("lynis")
declare -a MANTLE_INSTALL_PACKAGES_ZYPPER=("lynis")
declare -a MANTLE_INSTALL_NATIVE_VERIFY_COMMANDS=("lynis")

mantle_install_native_package_main "$@"
