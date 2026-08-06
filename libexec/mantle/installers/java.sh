#!/usr/bin/env bash
# shellcheck shell=bash
# Install a JDK with the host's native package manager.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

java_version="${JAVA_VERSION:-21}"
version_was_requested="0"
declare -a native_arguments=()

while (($# > 0)); do
	case "$1" in
	--version)
		if (($# < 2)) || [[ ! "${2:-}" =~ ^[0-9]+$ ]]; then
			mantle_log_error "--version requires a JDK major version"
			exit 64
		fi
		java_version="$2"
		version_was_requested="1"
		shift 2
		;;
	--help | -h)
		printf "Usage: mantle install java [--version MAJOR] [--manager MANAGER] [--update-index] [--force] [--dry-run] [--help]\n"
		exit 0
		;;
	*)
		native_arguments+=("$1")
		shift
		;;
	esac
done

if [[ "${version_was_requested}" == "1" ]]; then
	native_arguments+=("--force")
fi

MANTLE_INSTALL_TOOL_NAME="java"
declare -a MANTLE_INSTALL_PACKAGES_APT=("openjdk-${java_version}-jdk")
declare -a MANTLE_INSTALL_PACKAGES_BREW_CASK=("temurin@${java_version}")
declare -a MANTLE_INSTALL_PACKAGES_DNF=("java-${java_version}-openjdk-devel")
declare -a MANTLE_INSTALL_PACKAGES_PACMAN=("jdk${java_version}-openjdk")
declare -a MANTLE_INSTALL_PACKAGES_YUM=("java-${java_version}-openjdk-devel")
declare -a MANTLE_INSTALL_PACKAGES_ZYPPER=("java-${java_version}-openjdk-devel")
declare -a MANTLE_INSTALL_NATIVE_VERIFY_COMMANDS=("java" "javac")

mantle_install_native_package_main "${native_arguments[@]}"
