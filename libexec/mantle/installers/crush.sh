#!/usr/bin/env bash
# shellcheck shell=bash
# Install charmbracelet/crush from a verified GitHub release.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="crush"
MANTLE_INSTALL_GITHUB_OWNER="charmbracelet"
MANTLE_INSTALL_GITHUB_REPOSITORY="crush"
MANTLE_INSTALL_ASSET_TEMPLATE="crush_{{version}}_{{platform}}_{{arch}}.tar.gz"
MANTLE_INSTALL_PLATFORM_LINUX="Linux"
MANTLE_INSTALL_PLATFORM_DARWIN="Darwin"
MANTLE_INSTALL_ARCH_X86_64="x86_64"
MANTLE_INSTALL_ARCH_ARM64="arm64"
MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE="checksums.txt"
MANTLE_INSTALL_ARCHIVE_FORMAT="tar.gz"
MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE="crush"
MANTLE_INSTALL_BINARY_NAME="crush"
declare -a MANTLE_INSTALL_VERIFY_ARGUMENTS=("--version")

mantle_install_github_main "$@"
