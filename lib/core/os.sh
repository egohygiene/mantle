#!/usr/bin/env bash
# shellcheck shell=bash
#
# Detect the operating-system family, architecture, distribution, and runtime
# isolation characteristics used by Mantle.

if [[ -n "${BASH_VERSION:-}" && "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "[mantle:error] lib/core/os.sh is internal and must be sourced\n" >&2
	exit 64
fi

if [[ "${MANTLE_OS_LIBRARY_LOADED:-0}" == "1" ]]; then
	return 0
fi

__mantle_os_kernel="$(uname -s 2>/dev/null)" || __mantle_os_kernel="unknown"

case "${__mantle_os_kernel}" in
Darwin)
	MANTLE_OS_FAMILY="darwin"
	;;
Linux)
	MANTLE_OS_FAMILY="linux"
	;;
CYGWIN* | MINGW* | MSYS*)
	MANTLE_OS_FAMILY="windows"
	;;
*)
	MANTLE_OS_FAMILY="unknown"
	;;
esac

MANTLE_OS_KERNEL="${__mantle_os_kernel}"
MANTLE_OS_ARCH_RAW="$(uname -m 2>/dev/null)" || MANTLE_OS_ARCH_RAW="unknown"

case "${MANTLE_OS_ARCH_RAW}" in
amd64 | x86_64)
	MANTLE_OS_ARCH="x86_64"
	;;
aarch64 | arm64)
	MANTLE_OS_ARCH="arm64"
	;;
armv6*)
	MANTLE_OS_ARCH="armv6"
	;;
armv7*)
	MANTLE_OS_ARCH="armv7"
	;;
i386 | i486 | i586 | i686 | x86)
	MANTLE_OS_ARCH="x86"
	;;
ppc64le)
	MANTLE_OS_ARCH="ppc64le"
	;;
riscv64)
	MANTLE_OS_ARCH="riscv64"
	;;
s390x)
	MANTLE_OS_ARCH="s390x"
	;;
*)
	MANTLE_OS_ARCH="${MANTLE_OS_ARCH_RAW:-unknown}"
	;;
esac

MANTLE_OS_DISTRO="unknown"
MANTLE_OS_VERSION_ID="unknown"

case "${MANTLE_OS_FAMILY}" in
darwin)
	MANTLE_OS_DISTRO="macos"
	if command -v sw_vers >/dev/null 2>&1; then
		MANTLE_OS_VERSION_ID="$(sw_vers -productVersion 2>/dev/null)" ||
			MANTLE_OS_VERSION_ID="unknown"
	fi
	;;
linux)
	if [[ -r "/etc/os-release" ]]; then
		while IFS="=" read -r __mantle_os_release_key __mantle_os_release_value; do
			case "${__mantle_os_release_key}" in
			ID)
				__mantle_os_release_value="${__mantle_os_release_value#\"}"
				__mantle_os_release_value="${__mantle_os_release_value%\"}"
				__mantle_os_release_value="${__mantle_os_release_value#\'}"
				__mantle_os_release_value="${__mantle_os_release_value%\'}"
				MANTLE_OS_DISTRO="${__mantle_os_release_value:-unknown}"
				;;
			VERSION_ID)
				__mantle_os_release_value="${__mantle_os_release_value#\"}"
				__mantle_os_release_value="${__mantle_os_release_value%\"}"
				__mantle_os_release_value="${__mantle_os_release_value#\'}"
				__mantle_os_release_value="${__mantle_os_release_value%\'}"
				MANTLE_OS_VERSION_ID="${__mantle_os_release_value:-unknown}"
				;;
			esac
		done <"/etc/os-release"
	fi
	;;
windows)
	MANTLE_OS_DISTRO="windows"
	;;
esac

MANTLE_IS_WSL="0"

if [[ "${MANTLE_OS_FAMILY}" == "linux" ]]; then
	if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]]; then
		MANTLE_IS_WSL="1"
	elif [[ -r "/proc/version" ]] &&
		grep -qiE "(microsoft|wsl)" "/proc/version" 2>/dev/null; then
		MANTLE_IS_WSL="1"
	fi
fi

MANTLE_IS_CONTAINER="0"

if [[ -n "${container:-}" || -e "/.dockerenv" || -e "/run/.containerenv" ]]; then
	MANTLE_IS_CONTAINER="1"
elif [[ -r "/proc/1/cgroup" ]] &&
	grep -qE "(docker|containerd|kubepods|libpod|lxc)" "/proc/1/cgroup" 2>/dev/null; then
	MANTLE_IS_CONTAINER="1"
fi

export MANTLE_OS_FAMILY
export MANTLE_OS_KERNEL
export MANTLE_OS_ARCH
export MANTLE_OS_ARCH_RAW
export MANTLE_OS_DISTRO
export MANTLE_OS_VERSION_ID
export MANTLE_IS_WSL
export MANTLE_IS_CONTAINER

# @description Print Mantle's normalized operating-system family.
# @stdout darwin, linux, windows, or unknown.
mantle_os_detect() {
	printf "%s\n" "${MANTLE_OS_FAMILY:-unknown}"
}

# @description Print Mantle's normalized machine architecture.
# @stdout A normalized architecture such as x86_64 or arm64.
mantle_os_arch() {
	printf "%s\n" "${MANTLE_OS_ARCH:-unknown}"
}

# @description Print the detected operating-system distribution identifier.
# @stdout A distribution identifier such as macos, ubuntu, or unknown.
mantle_os_distro() {
	printf "%s\n" "${MANTLE_OS_DISTRO:-unknown}"
}

# @description Return whether Mantle is running on macOS.
# @exitcode 0 Mantle is running on macOS.
# @exitcode 1 Mantle is not running on macOS.
mantle_os_is_macos() {
	[[ "${MANTLE_OS_FAMILY:-unknown}" == "darwin" ]]
}

# @description Return whether Mantle is running on Linux.
# @exitcode 0 Mantle is running on Linux.
# @exitcode 1 Mantle is not running on Linux.
mantle_os_is_linux() {
	[[ "${MANTLE_OS_FAMILY:-unknown}" == "linux" ]]
}

# @description Return whether Mantle is running in a Windows-compatible shell.
# @exitcode 0 Mantle is running in a Windows-compatible shell.
# @exitcode 1 Mantle is not running in a Windows-compatible shell.
mantle_os_is_windows() {
	[[ "${MANTLE_OS_FAMILY:-unknown}" == "windows" ]]
}

# @description Return whether Mantle is running under Windows Subsystem for Linux.
# @exitcode 0 Mantle is running under WSL.
# @exitcode 1 Mantle is not running under WSL.
mantle_os_is_wsl() {
	[[ "${MANTLE_IS_WSL:-0}" == "1" ]]
}

# @description Return whether Mantle is running inside a detected container.
# @exitcode 0 Mantle is running inside a container.
# @exitcode 1 Mantle is not running inside a detected container.
mantle_os_is_container() {
	[[ "${MANTLE_IS_CONTAINER:-0}" == "1" ]]
}

# @description Print a human-readable name for the active operating system.
# @stdout WSL, macOS, Linux, Windows, or Unknown.
mantle_os_name() {
	if mantle_os_is_wsl; then
		printf "WSL\n"
	elif mantle_os_is_macos; then
		printf "macOS\n"
	elif mantle_os_is_linux; then
		printf "Linux\n"
	elif mantle_os_is_windows; then
		printf "Windows\n"
	else
		printf "Unknown\n"
	fi
}

MANTLE_OS_LIBRARY_LOADED="1"

unset __mantle_os_kernel
unset __mantle_os_release_key
unset __mantle_os_release_value

return 0
