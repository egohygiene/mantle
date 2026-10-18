#!/usr/bin/env bash
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Exercise Mantle's real copy-install lifecycle in an isolated temporary home.

set -o errexit
set -o nounset
set -o pipefail

MANTLE_SMOKE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MANTLE_SMOKE_ROOT="$(cd "${MANTLE_SMOKE_DIRECTORY}/../.." && pwd -P)"
MANTLE_SMOKE_TEMP_PARENT="${TMPDIR:-/tmp}"
MANTLE_SMOKE_WORKSPACE="$(mktemp -d "${MANTLE_SMOKE_TEMP_PARENT%/}/mantle-install-smoke.XXXXXXXXXX")"
MANTLE_SMOKE_HOME="${MANTLE_SMOKE_WORKSPACE}/home"
MANTLE_SMOKE_PREFIX="${MANTLE_SMOKE_WORKSPACE}/prefix"

mantle_smoke_cleanup() {
	case "${MANTLE_SMOKE_WORKSPACE:-}" in
	"${MANTLE_SMOKE_TEMP_PARENT%/}"/mantle-install-smoke.*)
		rm -rf -- "${MANTLE_SMOKE_WORKSPACE}"
		;;
	*)
		printf "[mantle:smoke:error] refusing unsafe cleanup path: %s\n" \
			"${MANTLE_SMOKE_WORKSPACE:-<empty>}" >&2
		return 1
		;;
	esac
}

trap mantle_smoke_cleanup EXIT HUP INT TERM

mkdir -p \
	"${MANTLE_SMOKE_HOME}/.cache" \
	"${MANTLE_SMOKE_HOME}/.config" \
	"${MANTLE_SMOKE_HOME}/.local/share" \
	"${MANTLE_SMOKE_HOME}/.local/state" \
	"${MANTLE_SMOKE_HOME}/.runtime" \
	"${MANTLE_SMOKE_WORKSPACE}/tmp"
chmod 0700 "${MANTLE_SMOKE_HOME}/.runtime"

mantle_smoke_installer() {
	env -i \
		HOME="${MANTLE_SMOKE_HOME}" \
		PATH="/usr/local/bin:/usr/bin:/bin" \
		TERM="dumb" \
		TMPDIR="${MANTLE_SMOKE_WORKSPACE}/tmp" \
		XDG_CACHE_HOME="${MANTLE_SMOKE_HOME}/.cache" \
		XDG_CONFIG_HOME="${MANTLE_SMOKE_HOME}/.config" \
		XDG_DATA_HOME="${MANTLE_SMOKE_HOME}/.local/share" \
		XDG_RUNTIME_DIR="${MANTLE_SMOKE_HOME}/.runtime" \
		XDG_STATE_HOME="${MANTLE_SMOKE_HOME}/.local/state" \
		/bin/bash "${MANTLE_SMOKE_ROOT}/install.sh" \
		--prefix "${MANTLE_SMOKE_PREFIX}" \
		--no-shell-hook \
		"$@"
}

mantle_smoke_installer

if [[ ! -x "${MANTLE_SMOKE_PREFIX}/bin/mantle" ]]; then
	printf "[mantle:smoke:error] installed CLI is missing or not executable\n" >&2
	exit 1
fi

env -i \
	HOME="${MANTLE_SMOKE_HOME}" \
	PATH="/usr/local/bin:/usr/bin:/bin" \
	TERM="dumb" \
	XDG_CACHE_HOME="${MANTLE_SMOKE_HOME}/.cache" \
	XDG_CONFIG_HOME="${MANTLE_SMOKE_HOME}/.config" \
	XDG_DATA_HOME="${MANTLE_SMOKE_HOME}/.local/share" \
	XDG_RUNTIME_DIR="${MANTLE_SMOKE_HOME}/.runtime" \
	XDG_STATE_HOME="${MANTLE_SMOKE_HOME}/.local/state" \
	"${MANTLE_SMOKE_PREFIX}/bin/mantle" doctor >/dev/null

# A second copy installation proves that publication remains idempotent.
mantle_smoke_installer

MANTLE_SMOKE_STATUS="$(mantle_smoke_installer --status)"
case "${MANTLE_SMOKE_STATUS}" in
*"installed: yes"*"ownership: installer-owned"*) ;;
*)
	printf "[mantle:smoke:error] unexpected installed status:\n%s\n" \
		"${MANTLE_SMOKE_STATUS}" >&2
	exit 1
	;;
esac

mantle_smoke_installer --uninstall

if [[ -e "${MANTLE_SMOKE_PREFIX}" || -L "${MANTLE_SMOKE_PREFIX}" ]]; then
	printf "[mantle:smoke:error] uninstall left the temporary prefix behind\n" >&2
	exit 1
fi

for MANTLE_SMOKE_STARTUP_FILE in \
	"${MANTLE_SMOKE_HOME}/.bash_profile" \
	"${MANTLE_SMOKE_HOME}/.bashrc" \
	"${MANTLE_SMOKE_HOME}/.zshrc" \
	"${MANTLE_SMOKE_HOME}/.config/fish/conf.d/mantle.fish"; do
	if [[ -e "${MANTLE_SMOKE_STARTUP_FILE}" ]]; then
		printf "[mantle:smoke:error] smoke test mutated a startup file: %s\n" \
			"${MANTLE_SMOKE_STARTUP_FILE}" >&2
		exit 1
	fi
done

printf "Mantle temporary-prefix install smoke test passed.\n"
