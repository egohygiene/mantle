#!/usr/bin/env bats
# Behavioral tests for bin/encrypt-volume.

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

@test "encrypt-volume --help exits 0 and prints usage" {
	run_bin encrypt-volume --help
	assert_success
	assert_output_contains "Usage"
}

@test "encrypt-volume --version exits 0 and prints a version" {
	run_bin encrypt-volume --version
	assert_success
	assert_valid_version
}

@test "encrypt-volume unknown option exits non-zero" {
	run_bin encrypt-volume --no-such-flag
	assert_failure
}

@test "encrypt-volume requires root and fails without sudo" {
	make_stub "sudo" 1 ""
	run_bin encrypt-volume
	assert_failure
}
