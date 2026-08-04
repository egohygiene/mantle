#!/usr/bin/env bash
# shellcheck shell=bash
# Install crate-ci/typos from a verified GitHub release.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="typos"
MANTLE_INSTALL_GITHUB_OWNER="crate-ci"
MANTLE_INSTALL_GITHUB_REPOSITORY="typos"
MANTLE_INSTALL_ASSET_TEMPLATE="typos-v{{version}}-{{arch}}-{{platform}}.tar.gz"
MANTLE_INSTALL_PLATFORM_LINUX="unknown-linux-musl"
MANTLE_INSTALL_PLATFORM_DARWIN="apple-darwin"
MANTLE_INSTALL_ARCH_X86_64="x86_64"
MANTLE_INSTALL_ARCH_ARM64="aarch64"
MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE="sha256sums.txt"
MANTLE_INSTALL_ARCHIVE_FORMAT="tar.gz"
MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE="typos"
MANTLE_INSTALL_BINARY_NAME="typos"
declare -a MANTLE_INSTALL_VERIFY_ARGUMENTS=("--version")

mantle_install_github_main "$@"
