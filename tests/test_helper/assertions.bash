#!/usr/bin/env bash
# shellcheck shell=bash
#
# Custom Bats assertion helpers for the Mantle test suite.
#
# Source this file from test files:
#   load '../test_helper/assertions'

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "test_helper/assertions.bash must be sourced by Bats, not executed directly\n" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Output assertions.
# ---------------------------------------------------------------------------

# assert_output_contains — fail if $output does not contain the given string.
assert_output_contains() {
	local expected="${1:?assert_output_contains requires an argument}"
	if [[ "${output}" != *"${expected}"* ]]; then
		printf "Expected output to contain: %s\nActual output: %s\n" \
			"${expected}" "${output}" >&2
		return 1
	fi
}

# assert_output_not_contains — fail if $output contains the given string.
assert_output_not_contains() {
	local unexpected="${1:?assert_output_not_contains requires an argument}"
	if [[ "${output}" == *"${unexpected}"* ]]; then
		printf "Expected output NOT to contain: %s\nActual output: %s\n" \
			"${unexpected}" "${output}" >&2
		return 1
	fi
}

# assert_line_contains — fail if no $lines[] element contains the given string.
assert_line_contains() {
	local expected="${1:?}"
	local line
	for line in "${lines[@]}"; do
		if [[ "${line}" == *"${expected}"* ]]; then
			return 0
		fi
	done
	printf "Expected a line to contain: %s\nAll lines:\n%s\n" \
		"${expected}" "${output}" >&2
	return 1
}

# assert_stderr_contains — fail if $stderr does not contain the given string.
# Only meaningful when run has been called with run --separate-stderr or via
# a wrapper that separates them.
assert_stderr_contains() {
	local expected="${1:?}"
	if [[ "${stderr:-${output}}" != *"${expected}"* ]]; then
		printf "Expected stderr to contain: %s\nActual stderr: %s\n" \
			"${expected}" "${stderr:-${output}}" >&2
		return 1
	fi
}

# ---------------------------------------------------------------------------
# Exit-status assertions.
# ---------------------------------------------------------------------------

# assert_success — fail if the last run exited non-zero.
assert_success() {
	if [[ "${status}" -ne 0 ]]; then
		printf "Expected exit status 0, got %d\nOutput: %s\n" \
			"${status}" "${output}" >&2
		return 1
	fi
}

# assert_failure — fail if the last run exited zero.
assert_failure() {
	if [[ "${status}" -eq 0 ]]; then
		printf "Expected non-zero exit status\nOutput: %s\n" \
			"${output}" >&2
		return 1
	fi
}

# assert_status — fail unless the last run exited with the given status.
assert_status() {
	local expected="${1:?assert_status requires an expected status}"
	if [[ "${status}" -ne "${expected}" ]]; then
		printf "Expected exit status %d, got %d\nOutput: %s\n" \
			"${expected}" "${status}" "${output}" >&2
		return 1
	fi
}

# ---------------------------------------------------------------------------
# File and directory assertions.
# ---------------------------------------------------------------------------

# assert_file_exists — fail if a file does not exist.
assert_file_exists() {
	local path="${1:?}"
	if [[ ! -f "${path}" ]]; then
		printf "Expected file to exist: %s\n" "${path}" >&2
		return 1
	fi
}

# assert_file_not_exists — fail if a file exists.
assert_file_not_exists() {
	local path="${1:?}"
	if [[ -f "${path}" ]]; then
		printf "Expected file NOT to exist: %s\n" "${path}" >&2
		return 1
	fi
}

# assert_dir_exists — fail if a directory does not exist.
assert_dir_exists() {
	local path="${1:?}"
	if [[ ! -d "${path}" ]]; then
		printf "Expected directory to exist: %s\n" "${path}" >&2
		return 1
	fi
}

# assert_file_executable — fail if a file is not executable.
assert_file_executable() {
	local path="${1:?}"
	if [[ ! -x "${path}" ]]; then
		printf "Expected file to be executable: %s\n" "${path}" >&2
		return 1
	fi
}

# assert_file_not_executable — fail if a file is executable.
assert_file_not_executable() {
	local path="${1:?}"
	if [[ -x "${path}" ]]; then
		printf "Expected file NOT to be executable: %s\n" "${path}" >&2
		return 1
	fi
}

# assert_file_mode — fail if a file does not have the given octal permission.
assert_file_mode() {
	local path="${1:?}"
	local expected_mode="${2:?}"
	local actual_mode
	actual_mode="$(file_permissions "${path}")"
	if [[ "${actual_mode}" != "${expected_mode}" ]]; then
		printf "Expected mode %s on %s, got %s\n" \
			"${expected_mode}" "${path}" "${actual_mode}" >&2
		return 1
	fi
}

# assert_env_var_set — fail if an environment variable is not set or is empty.
assert_env_var_set() {
	local var_name="${1:?}"
	local var_value
	var_value="$(printenv "${var_name}" 2>/dev/null)" || {
		printf "Expected env var to be set: %s\n" "${var_name}" >&2
		return 1
	}
	if [[ -z "${var_value}" ]]; then
		printf "Expected env var to be non-empty: %s\n" "${var_name}" >&2
		return 1
	fi
}

# assert_env_var_not_set — fail if an environment variable is set.
assert_env_var_not_set() {
	local var_name="${1:?}"
	if printenv "${var_name}" >/dev/null 2>&1; then
		printf "Expected env var NOT to be set: %s\n" "${var_name}" >&2
		return 1
	fi
}
