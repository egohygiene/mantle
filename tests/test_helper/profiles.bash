#!/usr/bin/env bash
# shellcheck shell=bash
# Shared fixtures and public-interface helpers for profile/catalog integration.

# @description Copy only the installed Mantle surfaces into the isolated home.
profile_test_copy_tree() {
	PROFILE_ROOT="${TEST_HOME}/mantle-copy"
	mkdir -p "${PROFILE_ROOT}"
	cp -R "${MANTLE_ROOT}/.shellrc" \
		"${MANTLE_ROOT}/bin" "${MANTLE_ROOT}/config" \
		"${MANTLE_ROOT}/init" "${MANTLE_ROOT}/lib" \
		"${MANTLE_ROOT}/libexec" "${MANTLE_ROOT}/modules" \
		"${MANTLE_ROOT}/platforms" "${MANTLE_ROOT}/runtime" "${PROFILE_ROOT}/"
}

# @description Require Python only for on-demand metadata and fixture mutation.
profile_test_require_python() {
	if ! command -v python3 >/dev/null 2>&1; then
		skip "python3 is not available"
	fi
}

# @description Invoke a public metadata command with a clean environment.
# @arg $@ string Command and arguments.
profile_test_cli() {
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${PROFILE_ROOT}" \
		PATH="${PROFILE_TEST_PATH:-${PATH}}" TERM=dumb \
		"${PROFILE_ROOT}/bin/mantle" "$@"
}

# @description Assert trusted Python conditions against a JSON CLI result.
# @arg $1 string Python assertions with report and root variables available.
profile_test_json() {
	python3 - "${output}" "${PROFILE_ROOT}" "$1" <<'PY'
import json
import os
from pathlib import Path
import sys
report = json.loads(sys.argv[1])
root = Path(sys.argv[2])
assert report["schema_version"] == 1, report
exec(sys.argv[3])
PY
}

# @description Source the native runtime and execute trusted shell assertions.
# @arg $1 string bash, zsh, or fish.
# @arg $2 string Requested profile name.
# @arg $3 string Trusted commands using the selected shell's syntax.
profile_test_shell() {
	local shell_name="${1:?}" profile="${2:?}" commands="${3:?}"
	local executable
	executable="$(command -v "${shell_name}" || true)"
	if [[ -z "${executable}" ]]; then
		skip "${shell_name} is not available"
	fi
	case "${shell_name}" in
	bash)
		run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${PROFILE_ROOT}" MANTLE_PROFILE="${profile}" \
			XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" PATH="${PROFILE_TEST_PATH:-${PATH}}" TERM=dumb \
			MANTLE_CREATE_XDG_DIRECTORIES=0 LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" \
			"${executable}" --noprofile --norc -c 'source "$MANTLE_ROOT/.shellrc" || exit $?; eval "$1"' _ "${commands}"
		;;
	zsh)
		run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${PROFILE_ROOT}" MANTLE_PROFILE="${profile}" \
			XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" PATH="${PROFILE_TEST_PATH:-${PATH}}" TERM=dumb \
			MANTLE_CREATE_XDG_DIRECTORIES=0 LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" \
			"${executable}" --no-rcs -c 'source "$MANTLE_ROOT/.shellrc" || exit $?; eval "$1"' _ "${commands}"
		;;
	fish)
		run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${PROFILE_ROOT}" MANTLE_PROFILE="${profile}" \
			XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" PATH="${PROFILE_TEST_PATH:-${PATH}}" TERM=dumb \
			MANTLE_CREATE_XDG_DIRECTORIES=0 LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" \
			"${executable}" --no-config -c 'source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status; eval $argv[1]' "${commands}"
		;;
	esac
}
