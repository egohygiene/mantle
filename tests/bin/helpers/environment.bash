#!/usr/bin/env bash
# shellcheck shell=bash
#
# Environment isolation helpers for bin/ CLI tests.
#
# Source this file from Bats test files:
#   load '../helpers/environment'

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "helpers/environment.bash must be sourced by Bats, not executed directly\n" >&2
	exit 1
fi

# Resolve MANTLE_ROOT from the location of this file.
_BIN_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
MANTLE_ROOT="$(cd "${_BIN_TEST_DIR}/../.." && pwd -P)"
export MANTLE_ROOT

# ---------------------------------------------------------------------------
# Isolated test environment
# ---------------------------------------------------------------------------

# bin_test_setup — canonical setup for every bin/ test.
# Creates isolated HOME, XDG dirs, stub dir, and prepends stub dir to PATH.
bin_test_setup() {
	BIN_TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/mantle-bin-test-XXXXXX")"
	export BIN_TEST_HOME HOME="${BIN_TEST_HOME}"

	export XDG_CONFIG_HOME="${BIN_TEST_HOME}/.config"
	export XDG_CACHE_HOME="${BIN_TEST_HOME}/.cache"
	export XDG_DATA_HOME="${BIN_TEST_HOME}/.local/share"
	export XDG_STATE_HOME="${BIN_TEST_HOME}/.local/state"
	export XDG_RUNTIME_DIR="${BIN_TEST_HOME}/.runtime"

	mkdir -p \
		"${XDG_CONFIG_HOME}" \
		"${XDG_CACHE_HOME}" \
		"${XDG_DATA_HOME}" \
		"${XDG_STATE_HOME}" \
		"${XDG_RUNTIME_DIR}"
	chmod 0700 "${XDG_RUNTIME_DIR}"

	BIN_STUB_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mantle-bin-stubs-XXXXXX")"
	export BIN_STUB_DIR

	# Prepend stub dir so stubs shadow real commands.
	BIN_ORIGINAL_PATH="${PATH}"
	export PATH="${BIN_STUB_DIR}:${PATH}"

	# Ensure no terminal is detected in tests.
	export TERM=dumb
	export CI=true

	# Unset credentials and config that could leak from the developer environment.
	unset GH_TOKEN GITHUB_TOKEN GOOGLE_APPLICATION_CREDENTIALS \
		DOCKER_CONFIG KUBECONFIG AWS_PROFILE GCLOUD_CONFIG \
		GPG_AGENT_INFO SSH_AUTH_SOCK 2>/dev/null || true
}

# bin_test_teardown — canonical teardown for every bin/ test.
bin_test_teardown() {
	if [[ -n "${BIN_STUB_DIR:-}" && "${BIN_STUB_DIR}" == */mantle-bin-stubs-* ]]; then
		rm -rf "${BIN_STUB_DIR}"
	fi
	if [[ -n "${BIN_TEST_HOME:-}" && "${BIN_TEST_HOME}" == */mantle-bin-test-* ]]; then
		rm -rf "${BIN_TEST_HOME}"
	fi
	if [[ -n "${BIN_ORIGINAL_PATH:-}" ]]; then
		export PATH="${BIN_ORIGINAL_PATH}"
	fi
}

# ---------------------------------------------------------------------------
# Command runner
# ---------------------------------------------------------------------------

# run_bin — invoke a command from bin/ in an isolated environment.
# Usage: run_bin COMMAND [ARGS...]
run_bin() {
	local cmd="${1:?run_bin requires a command name}"
	shift
	local cmd_path="${MANTLE_ROOT}/bin/${cmd}"
	run env -i \
		HOME="${BIN_TEST_HOME:-${HOME}}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}" \
		XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}" \
		XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}" \
		MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${BIN_STUB_DIR:-/usr/local/bin}:${PATH}" \
		TERM=dumb \
		CI=true \
		"${cmd_path}" "$@"
}

# run_bin_with_env — invoke a command from bin/ with additional env vars.
# Usage: run_bin_with_env COMMAND KEY=VALUE... -- [ARGS...]
run_bin_with_env() {
	local cmd="${1:?run_bin_with_env requires a command name}"
	shift
	local -a extra_env=()
	while [[ "$#" -gt 0 && "$1" != "--" ]]; do
		extra_env+=("$1")
		shift
	done
	[[ "$1" == "--" ]] && shift
	local cmd_path="${MANTLE_ROOT}/bin/${cmd}"
	run env -i \
		HOME="${BIN_TEST_HOME:-${HOME}}" \
		XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}" \
		XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}" \
		XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}" \
		XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}" \
		MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${BIN_STUB_DIR:-/usr/local/bin}:${PATH}" \
		TERM=dumb \
		CI=true \
		"${extra_env[@]}" \
		"${cmd_path}" "$@"
}
