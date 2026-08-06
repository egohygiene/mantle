#!/usr/bin/env bash
# shellcheck shell=bash
#
# Common Bats test helpers for the Mantle test suite.
#
# Source this file from test files:
#   load '../test_helper/common'

# ---------------------------------------------------------------------------
# Guard against direct execution.
# ---------------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "test_helper/common.bash must be sourced by Bats, not executed directly\n" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Resolve the Mantle repository root relative to this file.
# ---------------------------------------------------------------------------

MANTLE_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
MANTLE_ROOT="$(cd "${MANTLE_TEST_DIR}/.." && pwd -P)"
export MANTLE_TEST_DIR MANTLE_ROOT

# ---------------------------------------------------------------------------
# Isolated home and workspace setup.
# ---------------------------------------------------------------------------

# setup_isolated_home — create a per-test HOME in a temp directory.
# Call from Bats setup() functions.
setup_isolated_home() {
	local original_home="${HOME:-}"
	TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/mantle-test-home-XXXXXX")"
	export TEST_HOME HOME="${TEST_HOME}"

	export XDG_CONFIG_HOME="${TEST_HOME}/.config"
	export XDG_CACHE_HOME="${TEST_HOME}/.cache"
	export XDG_DATA_HOME="${TEST_HOME}/.local/share"
	export XDG_STATE_HOME="${TEST_HOME}/.local/state"
	export XDG_RUNTIME_DIR="${TEST_HOME}/.runtime"

	mkdir -p "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" \
		"${XDG_DATA_HOME}" "${XDG_STATE_HOME}" "${XDG_RUNTIME_DIR}"
	chmod 0700 "${XDG_RUNTIME_DIR}"

	unset GH_TOKEN GITHUB_TOKEN GITHUB_ACTOR SSH_AUTH_SOCK

	if [[ -n "${original_home}" && "${TEST_HOME}" == "${original_home}" ]]; then
		printf "refusing to run tests in the real HOME: %s\n" "${original_home}" >&2
		return 1
	fi
}

# teardown_isolated_home — remove the per-test HOME.
teardown_isolated_home() {
	if [[ -n "${TEST_HOME:-}" && "${TEST_HOME}" == */mantle-test-home-* ]]; then
		rm -rf "${TEST_HOME}"
	fi
}

# setup_clean_path — restrict PATH to essential system directories only.
setup_clean_path() {
	ORIGINAL_PATH="${PATH}"
	PATH="/usr/local/bin:/usr/bin:/bin"
	if [[ -d /usr/local/sbin ]]; then PATH="${PATH}:/usr/local/sbin"; fi
	if [[ -d /usr/sbin ]]; then PATH="${PATH}:/usr/sbin"; fi
	if [[ -d /sbin ]]; then PATH="${PATH}:/sbin"; fi
	export PATH
}

teardown_clean_path() {
	if [[ -n "${ORIGINAL_PATH:-}" ]]; then
		export PATH="${ORIGINAL_PATH}"
	fi
}

# ---------------------------------------------------------------------------
# Shell execution helpers.
# ---------------------------------------------------------------------------

# run_bash — run a command in a clean Bash subshell.
# Usage: run_bash 'command string'
run_bash() {
	run /bin/bash --noprofile --norc -c "$@"
}

# run_bash_source — source a file inside a clean Bash subshell.
# Usage: run_bash_source /path/to/file [env=value ...]
run_bash_source() {
	local source_file="$1"
	shift
	run env -i \
		HOME="${TEST_HOME:-${HOME}}" \
		MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${PATH}" \
		TERM=dumb \
		"$@" \
		/bin/bash --noprofile --norc -c "source '${source_file}'"
}

# run_zsh_source — source a file inside a clean Zsh subshell.
run_zsh_source() {
	local source_file="$1"
	shift
	if ! command -v zsh >/dev/null 2>&1; then
		skip "zsh is not available"
	fi
	run env -i \
		HOME="${TEST_HOME:-${HOME}}" \
		MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${PATH}" \
		TERM=dumb \
		"$@" \
		zsh --no-rcs -c "source '${source_file}'"
}

# run_bash_env — run a bash command with a clean environment and explicit vars.
# Usage: run_bash_env "VAR=value ..." "command string"
run_bash_env() {
	local env_vars="$1"
	local command_string="$2"
	run env -i \
		HOME="${TEST_HOME:-${HOME}}" \
		MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${PATH}" \
		TERM=dumb \
		${env_vars} \
		/bin/bash --noprofile --norc -c "${command_string}"
}

# ---------------------------------------------------------------------------
# Stub helpers.
# ---------------------------------------------------------------------------

# setup_stub_dir — create a per-test stub directory and prepend it to PATH.
setup_stub_dir() {
	STUB_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mantle-test-stubs-XXXXXX")"
	export STUB_DIR
	export PATH="${STUB_DIR}:${PATH}"
}

teardown_stub_dir() {
	if [[ -n "${STUB_DIR:-}" && "${STUB_DIR}" == */mantle-test-stubs-* ]]; then
		rm -rf "${STUB_DIR}"
	fi
}

# create_stub — create an executable stub command.
# Usage: create_stub NAME [exit_code] [output]
create_stub() {
	local name="${1:?create_stub requires a name}"
	local exit_code="${2:-0}"
	local output="${3:-}"
	local stub_path="${STUB_DIR:?setup_stub_dir must be called first}/${name}"

	{
		printf "#!/bin/sh\n"
		if [[ -n "${output}" ]]; then
			printf 'printf "%%s\\n" %q\n' "${output}"
		fi
		printf "exit %d\n" "${exit_code}"
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# create_recording_stub — create a stub that records its arguments to a file.
# Usage: create_recording_stub NAME [exit_code]
create_recording_stub() {
	local name="${1:?create_recording_stub requires a name}"
	local exit_code="${2:-0}"
	local stub_path="${STUB_DIR:?setup_stub_dir must be called first}/${name}"
	local record_file="${STUB_DIR}/${name}.calls"

	{
		printf "#!/bin/sh\n"
		printf 'printf "%%s\\n" "$*" >> %q\n' "${record_file}"
		printf "exit %d\n" "${exit_code}"
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# stub_call_count — print the number of times a recording stub was called.
stub_call_count() {
	local name="${1:?}"
	local record_file="${STUB_DIR:-/dev/null}/${name}.calls"
	if [[ -f "${record_file}" ]]; then
		wc -l <"${record_file}" | tr -d ' '
	else
		printf "0\n"
	fi
}

# ---------------------------------------------------------------------------
# Git repository fixtures.
# ---------------------------------------------------------------------------

# create_git_repo — create a minimal temporary Git repository.
# Usage: GIT_REPO_DIR="$(create_git_repo)"
create_git_repo() {
	local repo_dir
	repo_dir="$(mktemp -d "${TMPDIR:-/tmp}/mantle-test-repo-XXXXXX")"
	git -C "${repo_dir}" init -q 2>/dev/null
	git -C "${repo_dir}" config user.email "test@mantle"
	git -C "${repo_dir}" config user.name "Mantle Test"
	touch "${repo_dir}/.gitkeep"
	git -C "${repo_dir}" add .gitkeep 2>/dev/null
	git -C "${repo_dir}" commit -q -m "init" 2>/dev/null
	printf "%s\n" "${repo_dir}"
}

# ---------------------------------------------------------------------------
# Shell availability skips.
# ---------------------------------------------------------------------------

require_zsh() {
	if ! command -v zsh >/dev/null 2>&1; then
		skip "zsh is not available on this system"
	fi
}

require_fish() {
	if ! command -v fish >/dev/null 2>&1; then
		skip "fish is not available on this system"
	fi
}

require_dash() {
	if ! command -v dash >/dev/null 2>&1; then
		skip "dash is not available on this system"
	fi
}

# ---------------------------------------------------------------------------
# Portable permission reading.
# ---------------------------------------------------------------------------

# file_permissions — print the octal permission bits of a file (portable).
file_permissions() {
	local file_path="${1:?}"
	if stat --version 2>/dev/null | grep -q GNU; then
		stat -c "%a" "${file_path}"
	else
		stat -f "%A" "${file_path}"
	fi
}
