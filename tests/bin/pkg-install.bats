#!/usr/bin/env bats
# Behavioral tests for bin/pkg-install.

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

@test "pkg-install --help exits 0 and prints usage" {
	run_bin pkg-install --help
	assert_success
	assert_output_contains "Usage"
}

@test "pkg-install --version exits 0 and prints a version" {
	run_bin pkg-install --version
	assert_success
	assert_valid_version
}

@test "pkg-install unknown option exits non-zero" {
	run_bin pkg-install --no-such-flag
	assert_failure
}

@test "pkg-install requires root and fails without sudo" {
	make_stub "sudo" 1 ""
	run_bin pkg-install curl
	assert_failure
}
