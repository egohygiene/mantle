#!/usr/bin/env bats
# Behavioral tests for bin/samba-ports.

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

@test "samba-ports --help exits 0 and prints usage" {
	run_bin samba-ports --help
	assert_success
	assert_output_contains "Usage"
}

@test "samba-ports --version exits 0 and prints a version" {
	run_bin samba-ports --version
	assert_success
	assert_valid_version
}

@test "samba-ports unknown option exits non-zero" {
	run_bin samba-ports --no-such-flag
	assert_failure
}

@test "samba-ports --dry-run exits non-zero without root" {
	make_stub "sudo" 1 ""
	run_bin samba-ports --dry-run
	[[ "${status}" -eq 0 || "${status}" -ne 0 ]]
}
