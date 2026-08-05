#!/usr/bin/env bats
# Behavioral tests for bin/passwordless-sudo.

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

@test "passwordless-sudo --help exits 0 and prints usage" {
	run_bin passwordless-sudo --help
	assert_success
	assert_output_contains "Usage"
}

@test "passwordless-sudo --version exits 0 and prints a version" {
	run_bin passwordless-sudo --version
	assert_success
	assert_valid_version
}

@test "passwordless-sudo unknown option exits non-zero" {
	run_bin passwordless-sudo --no-such-flag
	assert_failure
}

@test "passwordless-sudo --list exits non-zero without root" {
	make_stub "sudo" 1 ""
	run_bin passwordless-sudo --list
	[[ "${status}" -ne 0 ]]
}
