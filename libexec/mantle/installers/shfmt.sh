#!/usr/bin/env bash
# shellcheck shell=bash
# Install mvdan/shfmt from a verified GitHub release.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="shfmt"
MANTLE_INSTALL_GITHUB_OWNER="mvdan"
MANTLE_INSTALL_GITHUB_REPOSITORY="sh"
MANTLE_INSTALL_ASSET_TEMPLATE="shfmt_v{{version}}_{{platform}}_{{arch}}"
MANTLE_INSTALL_PLATFORM_LINUX="linux"
MANTLE_INSTALL_PLATFORM_DARWIN="darwin"
MANTLE_INSTALL_ARCH_X86_64="amd64"
MANTLE_INSTALL_ARCH_ARM64="arm64"
MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE="sha256sums.txt"
MANTLE_INSTALL_ARCHIVE_FORMAT="raw"
MANTLE_INSTALL_BINARY_NAME="shfmt"
declare -a MANTLE_INSTALL_VERIFY_ARGUMENTS=("--version")

mantle_install_github_main "$@"
