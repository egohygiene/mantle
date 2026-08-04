#!/usr/bin/env bash
# shellcheck shell=bash
# Install Pantheon Terminus from a verified GitHub release.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="terminus"
MANTLE_INSTALL_GITHUB_OWNER="pantheon-systems"
MANTLE_INSTALL_GITHUB_REPOSITORY="terminus"
MANTLE_INSTALL_ASSET_TEMPLATE="terminus.phar"
MANTLE_INSTALL_TAG_TEMPLATE="{{version}}"
MANTLE_INSTALL_CHECKSUM_ASSET_TEMPLATE="terminus.phar.sha256sum"
MANTLE_INSTALL_ARCHIVE_FORMAT="raw"
MANTLE_INSTALL_BINARY_NAME="terminus"
MANTLE_INSTALL_VERSION="${TERMINUS_VERSION:-}"
declare -a MANTLE_INSTALL_VERIFY_ARGUMENTS=("--version")

installer_dry_run="0"
for installer_argument in "$@"; do
	if [[ "${installer_argument}" == "--help" || "${installer_argument}" == "-h" ]]; then
		mantle_install_github_usage
		exit 0
	elif [[ "${installer_argument}" == "--dry-run" ]]; then
		installer_dry_run="1"
	fi
done

if [[ "${installer_dry_run}" == "0" ]] && ! mantle_guard_has_command php; then
	mantle_log_error "Terminus requires PHP 8.2 or newer; install PHP before Terminus"
	exit 69
fi

mantle_install_github_main "$@"
