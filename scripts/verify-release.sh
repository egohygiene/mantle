#!/usr/bin/env bash
# shellcheck shell=bash
# Verify that a Mantle source-distribution archive has a safe lifecycle.

set -o errexit
set -o nounset
set -o pipefail

ARCHIVE_PATH=""
RELEASE_VERSION=""
VERIFY_ROOT=""

usage() {
	printf "%s\n" \
		"Usage: scripts/verify-release.sh --archive PATH --version VERSION" \
		"" \
		"Extract and exercise Mantle's install, doctor, disable, enable, and" \
		"uninstall lifecycle inside an isolated temporary home."
}

cleanup() {
	local exit_status=$?

	if [[ -n "${VERIFY_ROOT}" && -d "${VERIFY_ROOT}" ]]; then
		rm -rf "${VERIFY_ROOT}"
	fi

	return "${exit_status}"
}

fail() {
	printf "[mantle:release:error] %s\n" "$1" >&2
	exit 1
}

parse_args() {
	while (($# > 0)); do
		case "$1" in
		--archive)
			(($# >= 2)) || fail "--archive requires a value"
			ARCHIVE_PATH="$2"
			shift 2
			;;
		--version)
			(($# >= 2)) || fail "--version requires a value"
			RELEASE_VERSION="$2"
			shift 2
			;;
		--help | -h)
			usage
			exit 0
			;;
		*)
			fail "unknown option: $1"
			;;
		esac
	done

	[[ -n "${ARCHIVE_PATH}" ]] || fail "--archive is required"
	[[ -n "${RELEASE_VERSION}" ]] || fail "--version is required"
	[[ -r "${ARCHIVE_PATH}" ]] || fail "archive is not readable: ${ARCHIVE_PATH}"
}

archive_is_safe() {
	local member_path=""

	while IFS= read -r member_path; do
		case "${member_path}" in
		/* | ../* | */../* | ..)
			return 1
			;;
		esac
	done < <(tar -tzf "${ARCHIVE_PATH}")
}

release_env() {
	env -i \
		HOME="${VERIFY_ROOT}/home" \
		XDG_CONFIG_HOME="${VERIFY_ROOT}/home/.config" \
		XDG_CACHE_HOME="${VERIFY_ROOT}/home/.cache" \
		XDG_DATA_HOME="${VERIFY_ROOT}/home/.local/share" \
		XDG_STATE_HOME="${VERIFY_ROOT}/home/.local/state" \
		XDG_RUNTIME_DIR="${VERIFY_ROOT}/home/.runtime" \
		PATH="/usr/local/bin:/usr/bin:/bin" \
		TERM=dumb \
		"$@"
}

main() {
	local release_root=""
	local install_prefix=""
	local installed_version=""

	parse_args "$@"
	archive_is_safe || fail "archive contains an unsafe member path"

	VERIFY_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mantle-release-verify-XXXXXXXX")"
	trap cleanup EXIT INT TERM
	mkdir -p "${VERIFY_ROOT}/home/.runtime"
	chmod 0700 "${VERIFY_ROOT}/home/.runtime"

	tar -xzf "${ARCHIVE_PATH}" -C "${VERIFY_ROOT}"
	release_root="${VERIFY_ROOT}/mantle-${RELEASE_VERSION}"
	install_prefix="${VERIFY_ROOT}/installed"
	[[ -x "${release_root}/install.sh" ]] || fail "release archive is missing an executable install.sh"
	[[ -r "${release_root}/VERSION" ]] || fail "release archive is missing VERSION"
	[[ "$(tr -d '\r\n' <"${release_root}/VERSION")" == "${RELEASE_VERSION}" ]] ||
		fail "release VERSION does not match the requested version"

	release_env "${release_root}/install.sh" \
		--pin "${RELEASE_VERSION}" \
		--prefix "${install_prefix}" \
		--shell bash

	[[ -x "${install_prefix}/bin/mantle" ]] || fail "installed mantle executable is missing"
	[[ -x "${install_prefix}/install.sh" ]] || fail "installed lifecycle entrypoint is missing"
	[[ -d "${install_prefix}/libexec/mantle/commands" ]] ||
		fail "installed command implementations are missing"

	installed_version="$(release_env "${install_prefix}/bin/mantle" version --short)"
	[[ "${installed_version}" == "${RELEASE_VERSION}" ]] ||
		fail "installed mantle version does not match the release version"

	# shellcheck disable=SC2016 # The isolated shell receives the literal variables.
	release_env /bin/bash --noprofile --norc -c '
		source "$HOME/.bashrc"
		test "${MANTLE_INTERACTIVE}" = "0"
		test "${MANTLE_ROOT}" = "'"${install_prefix}"'"
		mantle version --short
	' >/dev/null

	# shellcheck disable=SC2016 # The isolated shell receives the literal variables.
	release_env /bin/bash --noprofile --rcfile "${VERIFY_ROOT}/home/.bashrc" -ic '
		test "${MANTLE_INTERACTIVE}" = "1"
		test "${MANTLE_ROOT}" = "'"${install_prefix}"'"
	' >/dev/null 2>&1

	release_env "${install_prefix}/install.sh" --doctor --prefix "${install_prefix}" --shell bash
	release_env "${install_prefix}/install.sh" --disable --prefix "${install_prefix}" --shell bash
	if grep -Fq "# >>> mantle >>>" "${VERIFY_ROOT}/home/.bashrc"; then
		fail "disable left the installer-managed Bash activation block behind"
	fi

	release_env "${install_prefix}/install.sh" --enable --prefix "${install_prefix}" --shell bash
	grep -Fq "# >>> mantle >>>" "${VERIFY_ROOT}/home/.bashrc" ||
		fail "enable did not restore the installer-managed Bash activation block"

	release_env "${install_prefix}/install.sh" --uninstall --prefix "${install_prefix}" --shell bash
	[[ ! -e "${install_prefix}" ]] || fail "uninstall did not remove the install prefix"
	if grep -Fq "# >>> mantle >>>" "${VERIFY_ROOT}/home/.bashrc"; then
		fail "uninstall left the installer-managed Bash activation block behind"
	fi

	printf "[mantle:release] verified %s\n" "${ARCHIVE_PATH}"
}

main "$@"
