#!/usr/bin/env bash
# shellcheck shell=bash
# Install Homebrew on Linux through a reviewed, explicitly trusted installer script.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${MANTLE_ROOT:-}" ]]; then
	MANTLE_ROOT="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
fi
export MANTLE_ROOT

# shellcheck disable=SC1091
source "${MANTLE_ROOT}/lib/install/runtime.sh"

linuxbrew_installer_url="${LINUXBREW_INSTALLER_URL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}"
linuxbrew_installer_sha256="${LINUXBREW_INSTALLER_SHA256:-}"
accept_unverified_installer="0"
dry_run="0"

# @description Print mantle install linuxbrew usage.
mantle_install_linuxbrew_usage() {
	printf "%s\n" \
		"Usage: mantle install linuxbrew [--installer-url HTTPS_URL] [--sha256 HEX]" \
		"                         [--accept-unverified-installer] [--dry-run] [--help]" \
		"" \
		"Remote installer execution requires either a pinned SHA-256 digest or the" \
		"explicit --accept-unverified-installer acknowledgement."
}

while (($# > 0)); do
	case "$1" in
		--installer-url)
			if (($# < 2)) || [[ "${2:-}" != https://* ]]; then
				mantle_install_linuxbrew_usage >&2
				exit 64
			fi
			linuxbrew_installer_url="$2"
			shift 2
			;;
		--sha256)
			if (($# < 2)) || [[ ! "${2:-}" =~ ^[[:xdigit:]]{64}$ ]]; then
				mantle_install_linuxbrew_usage >&2
				exit 64
			fi
			linuxbrew_installer_sha256="$2"
			shift 2
			;;
		--accept-unverified-installer)
			accept_unverified_installer="1"
			shift
			;;
		--dry-run)
			dry_run="1"
			shift
			;;
		--help | -h)
			mantle_install_linuxbrew_usage
			exit 0
			;;
		*)
			mantle_log_error "Unknown argument: $1"
			mantle_install_linuxbrew_usage >&2
			exit 64
			;;
	esac
done

if [[ "${MANTLE_OS_FAMILY:-unknown}" != "linux" ]]; then
	mantle_log_error "$(mantle install linuxbrew) supports Linux only"
	exit 69
fi
if mantle_guard_has_command brew; then
	mantle_log_success "Homebrew is already available at $(command -v brew)"
	exit 0
fi
if [[ -z "${linuxbrew_installer_sha256}" && "${accept_unverified_installer}" != "1" ]]; then
	mantle_log_error "Refusing to execute a remote installer without verification"
	mantle_log_error "Provide --sha256 or explicitly use --accept-unverified-installer"
	exit 77
fi
if [[ "${dry_run}" == "1" ]]; then
	printf "installer_url: %s\n" "${linuxbrew_installer_url}"
	printf "checksum: %s\n" "${linuxbrew_installer_sha256:-explicitly accepted as unverified}"
	printf "+ env NONINTERACTIVE=1 HOMEBREW_NO_ANALYTICS=1 /bin/bash VERIFIED_INSTALLER_PATH\n"
	exit 0
fi
if ((EUID == 0)); then
	mantle_log_error "Homebrew must not be installed as root"
	exit 77
fi

linuxbrew_temporary_directory="$(mantle_install_filesystem_make_temporary_directory)"
trap 'mantle_install_filesystem_cleanup "${linuxbrew_temporary_directory:-}" >/dev/null 2>&1 || true' EXIT
linuxbrew_installer_path="${linuxbrew_temporary_directory}/install.sh"
mantle_install_download_file "${linuxbrew_installer_url}" "${linuxbrew_installer_path}"
if [[ -n "${linuxbrew_installer_sha256}" ]]; then
	mantle_install_checksum_verify "sha256" "${linuxbrew_installer_path}" "${linuxbrew_installer_sha256}"
else
	mantle_log_warn "Executing the Homebrew installer without a pinned checksum by explicit request"
fi
env NONINTERACTIVE=1 HOMEBREW_NO_ANALYTICS=1 /bin/bash "${linuxbrew_installer_path}"
if ! mantle_guard_has_command brew && [[ ! -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
	mantle_log_error "Homebrew was not found after installation"
	exit 1
fi
mantle_log_success "Installed Homebrew on Linux"
