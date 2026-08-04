#!/usr/bin/env bash
# shellcheck shell=bash
# Install HTTPie as an isolated Python CLI.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

MANTLE_INSTALL_TOOL_NAME="httpie"
MANTLE_INSTALL_PYTHON_PACKAGE="httpie"
MANTLE_INSTALL_VERSION="${HTTPIE_VERSION:-}"
declare -a MANTLE_INSTALL_PYTHON_EXECUTABLES=("http" "https")

mantle_install_python_tool_main "$@"
