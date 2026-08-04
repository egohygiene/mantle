#!/usr/bin/env bash
# shellcheck shell=bash
# Install reteps/dockerfmt from a GitHub release.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="dockerfmt"
MANTLE_INSTALL_GITHUB_OWNER="reteps"
MANTLE_INSTALL_GITHUB_REPOSITORY="dockerfmt"
MANTLE_INSTALL_ASSET_TEMPLATE="dockerfmt-v{{version}}-{{platform}}-{{arch}}.tar.gz"
MANTLE_INSTALL_PLATFORM_LINUX="linux"
MANTLE_INSTALL_PLATFORM_DARWIN="darwin"
MANTLE_INSTALL_ARCH_X86_64="amd64"
MANTLE_INSTALL_ARCH_ARM64="arm64"
MANTLE_INSTALL_ARCHIVE_FORMAT="tar.gz"
MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE="dockerfmt"
MANTLE_INSTALL_BINARY_NAME="dockerfmt"
declare -a MANTLE_INSTALL_VERIFY_ARGUMENTS=("version")

mantle_install_github_main "$@"
