#!/usr/bin/env bats
# Behavioral tests for bin/generate-password.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

# ---------------------------------------------------------------------------
# Help and version
# ---------------------------------------------------------------------------

@test "generate-password --help exits 0 and prints usage" {
	run_bin generate-password --help
	assert_success
	assert_output_contains "Usage"
}

@test "generate-password --version exits 0 and prints a version" {
	run_bin generate-password --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Basic generation (requires real openssl)
# ---------------------------------------------------------------------------

@test "generate-password succeeds and stdout contains only the password line" {
	if ! command -v openssl >/dev/null 2>&1; then skip "openssl not available"; fi
	run_bin generate-password
	assert_success
	# stdout must be non-empty
	[[ -n "${output}" ]]
	# URL-safe base64 alphabet only (A-Za-z0-9_-)
	printf "%s\n" "${output}" | grep -qE '^[A-Za-z0-9_-]+$'
}

@test "generate-password --length 16 produces exactly 16-character password" {
	if ! command -v openssl >/dev/null 2>&1; then skip "openssl not available"; fi
	run_bin generate-password --length 16
	assert_success
	[[ "${#output}" -eq 16 ]]
}

@test "generate-password --length 1 produces a single character" {
	if ! command -v openssl >/dev/null 2>&1; then skip "openssl not available"; fi
	run_bin generate-password --length 1
	assert_success
	[[ "${#output}" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# Stdout is clean (no progress messages)
# ---------------------------------------------------------------------------

@test "generate-password stdout contains only the password without diagnostics" {
	if ! command -v openssl >/dev/null 2>&1; then skip "openssl not available"; fi
	run_bin generate-password --quiet
	assert_success
	# Only one line on stdout
	local line_count
	line_count="$(printf "%s\n" "${output}" | grep -c '.' || true)"
	[[ "${line_count}" -le 1 ]]
}

# ---------------------------------------------------------------------------
# Invalid usage
# ---------------------------------------------------------------------------

@test "generate-password --length 0 exits non-zero" {
	run_bin generate-password --length 0
	assert_failure
}

@test "generate-password --length not-a-number exits non-zero" {
	run_bin generate-password --length not-a-number
	assert_failure
}

@test "generate-password unknown option exits non-zero" {
	run_bin generate-password --no-such-flag
	assert_failure
}

# ---------------------------------------------------------------------------
# Clipboard stubs (no real clipboard writes)
# ---------------------------------------------------------------------------

@test "generate-password --copy uses clipboard backend stub without real clipboard" {
	if ! command -v openssl >/dev/null 2>&1; then skip "openssl not available"; fi
	stub_pbcopy
	run_bin generate-password --copy
	assert_success
}
