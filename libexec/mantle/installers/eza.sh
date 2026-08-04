#!/usr/bin/env bash
# shellcheck shell=bash
# Install eza-community/eza from a verified GitHub release.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="eza"
MANTLE_INSTALL_GITHUB_OWNER="eza-community"
MANTLE_INSTALL_GITHUB_REPOSITORY="eza"
MANTLE_INSTALL_ASSET_TEMPLATE="eza_{{arch}}-{{platform}}.tar.gz"
MANTLE_INSTALL_PLATFORM_LINUX="unknown-linux-gnu"
MANTLE_INSTALL_PLATFORM_DARWIN="apple-darwin"
MANTLE_INSTALL_ARCH_X86_64="x86_64"
MANTLE_INSTALL_ARCH_ARM64="aarch64"
MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE="eza.sha256sum"
MANTLE_INSTALL_ARCHIVE_FORMAT="tar.gz"
MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE="eza"
MANTLE_INSTALL_BINARY_NAME="eza"
declare -a MANTLE_INSTALL_VERIFY_ARGUMENTS=("--version")

mantle_install_github_main "$@"
