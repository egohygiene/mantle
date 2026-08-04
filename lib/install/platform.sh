#!/usr/bin/env bash
# shellcheck shell=bash
#
# Map Mantle's normalized platform metadata to upstream release naming.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/install/platform.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_INSTALL_PLATFORM_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

# @description Print Mantle's normalized operating-system family.
# @stdout darwin, linux, windows, or unknown.
mantle_install_platform_family() {
	if [[ -n "${MANTLE_OS_FAMILY:-}" ]]; then
		printf "%s\n" "${MANTLE_OS_FAMILY}"
	elif declare -F mantle_os_detect >/dev/null 2>&1; then
		mantle_os_detect
	else
		return 69
	fi
}

# @description Print Mantle's normalized machine architecture.
# @stdout A normalized architecture such as x86_64 or arm64.
mantle_install_platform_architecture() {
	if [[ -n "${MANTLE_OS_ARCH:-}" ]]; then
		printf "%s\n" "${MANTLE_OS_ARCH}"
	elif declare -F mantle_os_arch >/dev/null 2>&1; then
		mantle_os_arch
	else
		return 69
	fi
}

# @description Map the current OS family to upstream release terminology.
# @arg $1 string Optional Linux name, default linux.
# @arg $2 string Optional macOS name, default darwin.
# @arg $3 string Optional Windows name, default windows.
# @exitcode 64 Too many mapping arguments were supplied.
# @exitcode 69 Platform metadata is unavailable.
mantle_install_platform_map_family() {
	local linux_name="${1:-linux}"
	local darwin_name="${2:-darwin}"
	local windows_name="${3:-windows}"
	local platform_family=""

	if (($# > 3)); then
		return 64
	fi

	platform_family="$(mantle_install_platform_family)" || return $?

	case "${platform_family}" in
		linux)
			printf "%s\n" "${linux_name}"
			;;
		darwin)
			printf "%s\n" "${darwin_name}"
			;;
		windows)
			printf "%s\n" "${windows_name}"
			;;
		*)
			mantle_log_error "Unsupported operating system: ${platform_family}"
			return 69
			;;
	esac
}

# @description Map the current architecture to upstream release terminology.
# @arg $1 string Optional x86_64 name, default amd64.
# @arg $2 string Optional arm64 name, default arm64.
# @arg $3 string Optional armv7 name, default armv7.
# @arg $4 string Optional armv6 name, default armv6.
# @arg $5 string Optional x86 name, default 386.
# @arg $6 string Optional ppc64le name, default ppc64le.
# @arg $7 string Optional riscv64 name, default riscv64.
# @arg $8 string Optional s390x name, default s390x.
# @exitcode 64 Too many mapping arguments were supplied.
# @exitcode 69 Architecture metadata is unavailable or unsupported.
mantle_install_platform_map_architecture() {
	local x86_64_name="${1:-amd64}"
	local arm64_name="${2:-arm64}"
	local armv7_name="${3:-armv7}"
	local armv6_name="${4:-armv6}"
	local x86_name="${5:-386}"
	local ppc64le_name="${6:-ppc64le}"
	local riscv64_name="${7:-riscv64}"
	local s390x_name="${8:-s390x}"
	local architecture=""

	if (($# > 8)); then
		return 64
	fi

	architecture="$(mantle_install_platform_architecture)" || return $?

	case "${architecture}" in
		amd64 | x86_64)
			printf "%s\n" "${x86_64_name}"
			;;
		aarch64 | arm64)
			printf "%s\n" "${arm64_name}"
			;;
		armv7 | armv7l)
			printf "%s\n" "${armv7_name}"
			;;
		armv6 | armv6l)
			printf "%s\n" "${armv6_name}"
			;;
		i386 | i486 | i586 | i686 | x86)
			printf "%s\n" "${x86_name}"
			;;
		ppc64le)
			printf "%s\n" "${ppc64le_name}"
			;;
		riscv64)
			printf "%s\n" "${riscv64_name}"
			;;
		s390x)
			printf "%s\n" "${s390x_name}"
			;;
		*)
			mantle_log_error "Unsupported architecture: ${architecture}"
			return 69
			;;
	esac
}

MANTLE_INSTALL_PLATFORM_LIBRARY_LOADED="1"

return 0
