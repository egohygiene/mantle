#!/usr/bin/env bats
# Behavioral tests for bin/remove-pdf-password.

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

@test "remove-pdf-password --help exits 0 and prints usage" {
	run_bin remove-pdf-password --help
	assert_success
	assert_output_contains "Usage"
}

@test "remove-pdf-password --version exits 0 and prints a version" {
	run_bin remove-pdf-password --version
	assert_success
	assert_valid_version
}

@test "remove-pdf-password unknown option exits non-zero" {
	run_bin remove-pdf-password --no-such-flag
	assert_failure
}

@test "remove-pdf-password exits non-zero without arguments" {
	run_bin remove-pdf-password
	assert_failure
}

@test "remove-pdf-password exits non-zero when qpdf is unavailable" {
	make_stub "qpdf" 127 ""
	run_bin remove-pdf-password locked.pdf
	assert_failure
}
