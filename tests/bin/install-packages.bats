#!/usr/bin/env bats
# Behavioral tests for bin/install-packages.

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

@test "install-packages --help exits 0 and prints usage" {
	run_bin install-packages --help
	assert_success
	assert_output_contains "Usage"
}

@test "install-packages --version exits 0 and prints a version" {
	run_bin install-packages --version
	assert_success
	assert_valid_version
}

@test "install-packages unknown option exits non-zero" {
	run_bin install-packages --no-such-flag
	assert_failure
}

@test "install-packages requires root and fails without sudo" {
	make_stub "sudo" 1 ""
	run_bin install-packages curl
	assert_failure
}
