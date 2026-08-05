#!/usr/bin/env bash
# shellcheck shell=bash
#
# Assertion helpers for bin/ CLI tests.
#
# Source this file from Bats test files:
#   load '../helpers/assertions'

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "helpers/assertions.bash must be sourced by Bats, not executed directly\n" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

assert_output_contains() {
	local expected="${1:?}"
	if [[ "${output}" != *"${expected}"* ]]; then
		printf "Expected output to contain: %s\nActual output:\n%s\n" \
			"${expected}" "${output}" >&2
		return 1
	fi
}

assert_output_not_contains() {
	local unexpected="${1:?}"
	if [[ "${output}" == *"${unexpected}"* ]]; then
		printf "Expected output NOT to contain: %s\nActual output:\n%s\n" \
			"${unexpected}" "${output}" >&2
		return 1
	fi
}

assert_line_contains() {
	local expected="${1:?}"
	local line
	for line in "${lines[@]}"; do
		[[ "${line}" == *"${expected}"* ]] && return 0
	done
	printf "Expected a line to contain: %s\nAll output:\n%s\n" \
		"${expected}" "${output}" >&2
	return 1
}

# ---------------------------------------------------------------------------
# Exit status
# ---------------------------------------------------------------------------

assert_success() {
	if [[ "${status}" -ne 0 ]]; then
		printf "Expected exit 0, got %d\nOutput:\n%s\n" "${status}" "${output}" >&2
		return 1
	fi
}

assert_failure() {
	if [[ "${status}" -eq 0 ]]; then
		printf "Expected non-zero exit, got 0\nOutput:\n%s\n" "${output}" >&2
		return 1
	fi
}

assert_status() {
	local expected="${1:?}"
	if [[ "${status}" -ne "${expected}" ]]; then
		printf "Expected exit %d, got %d\nOutput:\n%s\n" \
			"${expected}" "${status}" "${output}" >&2
		return 1
	fi
}

# ---------------------------------------------------------------------------
# Version string
# ---------------------------------------------------------------------------

# assert_valid_version — fail unless output contains a semver-like version.
assert_valid_version() {
	if ! printf "%s\n" "${output}" | grep -qE '[0-9]+\.[0-9]+(\.[0-9]+)?'; then
		printf "Expected output to contain a version number\nActual output:\n%s\n" \
			"${output}" >&2
		return 1
	fi
}

# ---------------------------------------------------------------------------
# Files and directories
# ---------------------------------------------------------------------------

assert_file_exists() {
	local path="${1:?}"
	if [[ ! -f "${path}" ]]; then
		printf "Expected file to exist: %s\n" "${path}" >&2
		return 1
	fi
}

assert_file_not_exists() {
	local path="${1:?}"
	if [[ -f "${path}" ]]; then
		printf "Expected file NOT to exist: %s\n" "${path}" >&2
		return 1
	fi
}

assert_dir_exists() {
	local path="${1:?}"
	if [[ ! -d "${path}" ]]; then
		printf "Expected directory to exist: %s\n" "${path}" >&2
		return 1
	fi
}

assert_file_executable() {
	local path="${1:?}"
	if [[ ! -x "${path}" ]]; then
		printf "Expected file to be executable: %s\n" "${path}" >&2
		return 1
	fi
}
