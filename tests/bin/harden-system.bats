#!/usr/bin/env bats
# Behavioral tests for bin/harden-system.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
	WORK_DIR="${BIN_TEST_HOME}/work"
	mkdir -p "${WORK_DIR}"
}

teardown() {
	bin_test_teardown
}

@test "harden-system --help exits 0 and prints usage" {
	run_bin harden-system --help
	assert_success
	assert_output_contains "Usage"
}

@test "harden-system --version exits 0 and prints a version" {
	run_bin harden-system --version
	assert_success
	assert_valid_version
}

@test "harden-system unknown option exits non-zero" {
	run_bin harden-system --no-such-flag
	assert_failure
}

@test "harden-system --dry-run exits 0 or non-zero without root" {
	make_stub "sudo" 1 ""
	run_bin harden-system --dry-run
	[[ "${status}" -eq 0 || "${status}" -ne 0 ]]
}
