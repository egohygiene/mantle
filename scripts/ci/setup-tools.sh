#!/usr/bin/env bash
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Install only reviewed CI artifacts; never execute an unverified download.

set -o errexit
set -o nounset
set -o pipefail

CI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
CI_LOCKFILE="${CI_ROOT}/config/ci-tools.lock.tsv"
CI_PREFIX=""
CI_TEMP=""

# Reuse the portable acquisition primitives without activating the shell runtime.
# shellcheck source=../../lib/core/guards.sh
source "${CI_ROOT}/lib/core/guards.sh"
# shellcheck source=../../lib/core/logging.sh
source "${CI_ROOT}/lib/core/logging.sh"
# shellcheck source=../../lib/install/download.sh
source "${CI_ROOT}/lib/install/download.sh"
# shellcheck source=../../lib/install/checksum.sh
source "${CI_ROOT}/lib/install/checksum.sh"

# @description Remove this invocation's private download and extraction directory.
# @noargs
# @exitcode 0 Cleanup completed or no temporary directory was allocated.
ci_cleanup() {
	if [[ -n "${CI_TEMP}" ]]; then
		rm -rf "${CI_TEMP}"
	fi
}

# @description Select the supported native artifact platform.
# @noargs
# @stdout Platform key used by the CI lockfile.
# @exitcode 64 This host has no reviewed artifact mapping.
ci_platform() {
	local host_os=""
	local host_arch=""
	host_os="$(uname -s)"
	host_arch="$(uname -m)"
	case "${host_os}" in
	Linux) host_os="linux" ;;
	Darwin) host_os="darwin" ;;
	*)
		mantle_log_error "Unsupported CI tool platform: ${host_os}/${host_arch}"
		return 64
		;;
	esac
	case "${host_arch}" in
	x86_64 | amd64) host_arch="amd64" ;;
	arm64 | aarch64) host_arch="arm64" ;;
	*)
		mantle_log_error "Unsupported CI tool platform: ${host_os}/${host_arch}"
		return 64
		;;
	esac
	printf "%s-%s\n" "${host_os}" "${host_arch}"
}

# @description Resolve exactly one reviewed pin as literal TSV data, never shell code.
# @arg $1 string Tool name.
# @arg $2 string Native platform key.
# @stdout Matching five-column lockfile row.
# @exitcode 64 The lockfile is malformed or the selection is missing/ambiguous.
ci_resolve_pin() {
	awk -F '\t' -v tool="$1" -v platform="$2" '
		/^#/ || /^[[:space:]]*$/ { next }
		$1 == "tool" {
			headers++
			if ($0 != "tool\tversion\tplatform\turl\tsha256") bad = 1
			next
		}
		{
			if ($1 == "shdoc") version_ok = (length($2) == 40 && $2 ~ /^[0-9a-f]+$/)
			else version_ok = (($1 == "bats" || $1 == "shfmt") && $2 ~ /^[0-9]+[.][0-9]+[.][0-9]+$/)
			platform_ok = ($3 == "any" || $3 ~ /^(linux|darwin)-(amd64|arm64)$/)
			if (NF != 5 || !version_ok || !platform_ok || $4 !~ /^https:\/\// ||
			    length($5) != 64 || $5 !~ /^[0-9a-f]+$/) bad = 1
			if ($1 == tool && ($3 == platform || $3 == "any")) {
				count++
				row = $0
			}
		}
		END {
			if (bad || headers != 1 || count != 1) {
				printf "[mantle:error] Invalid, missing or duplicate CI tool pin: %s (%s)\n", tool, platform > "/dev/stderr"
				exit 64
			}
			print row
		}' "${CI_LOCKFILE}"
}

# @description Download, verify, then install a selected tool into an explicit prefix.
# @arg $1 string Tool name.
# @arg $2 string Resolved lockfile row.
# @exitcode 0 The verified artifact was installed.
# @exitcode 1 Acquisition, integrity verification, or installation failed.
# @exitcode 64 The reviewed identity is malformed.
ci_install_tool() {
	local tool="${1:?}"
	local version=""
	local platform=""
	local url=""
	local digest=""
	local artifact="${CI_TEMP}/${tool}.download"
	local ignored=""
	IFS=$'\t' read -r ignored version platform url digest <<<"$2"
	printf "CI tool: %s identity=%s platform=%s sha256=%s\n" "${tool}" "${version}" "${platform}" "${digest}"
	if ! mantle_install_download_file "${url}" "${artifact}"; then
		mantle_log_error "CI tool download failed: ${tool} (${version}) from ${url}; check availability and the reviewed pin"
		return 1
	fi
	if ! mantle_install_checksum_verify sha256 "${artifact}" "${digest}"; then
		mantle_log_error "CI tool checksum verification failed: ${tool} (${version}); artifact will not be installed or executed"
		return 1
	fi
	# No destination creation, extraction, chmod, installation or execution above this gate.
	case "${tool}" in
	bats)
		mkdir -p "${CI_TEMP}/bats"
		tar -xzf "${artifact}" -C "${CI_TEMP}/bats"
		/bin/bash "${CI_TEMP}/bats/bats-core-${version}/install.sh" "${CI_PREFIX}"
		;;
	shfmt | shdoc)
		mkdir -p "${CI_PREFIX}/bin"
		install -m 0755 "${artifact}" "${CI_PREFIX}/bin/${tool}"
		;;
	esac
}

# @description Parse explicit setup options and install the requested CI tools.
# @arg $@ string --prefix ABSOLUTE_PATH [--lockfile TRUSTED_TSV] TOOL...
# @stdout Tool identities and installation output.
# @stderr Actionable selection, acquisition and integrity errors.
# @exitcode 0 All requested tools were installed, or help was requested.
# @exitcode 64 Arguments or reviewed pins are invalid.
main() {
	local platform=""
	local tool=""
	local index=0
	local tools=()
	local pins=()
	while (($# > 0)); do
		case "$1" in
		--help)
			printf "Usage: %s --prefix ABSOLUTE_PATH [--lockfile TRUSTED_TSV] TOOL...\nTools: bats shfmt shdoc\n" "$0"
			return 0
			;;
		--prefix | --lockfile)
			if (($# < 2)) || [[ -z "$2" ]]; then
				mantle_log_error "Missing value for $1"
				return 64
			fi
			case "$1" in
			--prefix) CI_PREFIX="$2" ;;
			--lockfile) CI_LOCKFILE="$2" ;;
			esac
			shift 2
			;;
		bats | shfmt | shdoc)
			tools+=("$1")
			shift
			;;
		*)
			mantle_log_error "Unknown CI tool or option: $1"
			return 64
			;;
		esac
	done
	if [[ "${CI_PREFIX}" != /* || ! -r "${CI_LOCKFILE}" ]] || ((${#tools[@]} == 0)); then
		mantle_log_error "CI setup requires --prefix ABSOLUTE_PATH, a readable lockfile and at least one tool"
		return 64
	fi
	platform="$(ci_platform)"
	# Resolve every selection before downloading anything.
	for tool in "${tools[@]}"; do
		pins+=("$(ci_resolve_pin "${tool}" "${platform}")")
	done
	CI_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mantle-ci-tools.XXXXXXXX")"
	trap ci_cleanup EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM HUP
	for tool in "${tools[@]}"; do
		ci_install_tool "${tool}" "${pins[${index}]}"
		index=$((index + 1))
	done
}

main "$@"
