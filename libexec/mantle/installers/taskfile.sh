#!/usr/bin/env bash
# shellcheck shell=bash
# Install go-task/task from a verified GitHub release.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="task"
MANTLE_INSTALL_GITHUB_OWNER="go-task"
MANTLE_INSTALL_GITHUB_REPOSITORY="task"
MANTLE_INSTALL_ASSET_TEMPLATE="task_{{platform}}_{{arch}}.tar.gz"
MANTLE_INSTALL_PLATFORM_LINUX="linux"
MANTLE_INSTALL_PLATFORM_DARWIN="darwin"
MANTLE_INSTALL_ARCH_X86_64="amd64"
MANTLE_INSTALL_ARCH_ARM64="arm64"
MANTLE_INSTALL_ARCH_ARMV7="arm"
MANTLE_INSTALL_ARCH_ARMV6="arm"
MANTLE_INSTALL_ARCH_X86="386"
MANTLE_INSTALL_ARCH_RISCV64="riscv64"
MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE="task_checksums.txt"
MANTLE_INSTALL_ARCHIVE_FORMAT="tar.gz"
MANTLE_INSTALL_ARCHIVE_MEMBER_TEMPLATE="task"
MANTLE_INSTALL_BINARY_NAME="task"
declare -a MANTLE_INSTALL_VERIFY_ARGUMENTS=("--version")

mantle_install_github_main "$@"
