#!/usr/bin/env bash
# shellcheck shell=bash
# Install bootandy/dust from an official GitHub release.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="dust"
MANTLE_INSTALL_GITHUB_OWNER="bootandy"
MANTLE_INSTALL_GITHUB_REPOSITORY="dust"
MANTLE_INSTALL_ASSET_TEMPLATE="dust-v{{version}}-{{arch}}-{{platform}}.tar.gz"
MANTLE_INSTALL_PLATFORM_LINUX="unknown-linux-gnu"
MANTLE_INSTALL_PLATFORM_DARWIN="apple-darwin"
MANTLE_INSTALL_ARCH_X86_64="x86_64"
MANTLE_INSTALL_ARCH_ARM64="aarch64"
MANTLE_INSTALL_ARCHIVE_FORMAT="tar.gz"
MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE="dust-v{{version}}-{{arch}}-{{platform}}/dust"
MANTLE_INSTALL_BINARY_NAME="dust"
declare -a MANTLE_INSTALL_VERIFY_ARGUMENTS=("--version")

mantle_install_github_main "$@"
