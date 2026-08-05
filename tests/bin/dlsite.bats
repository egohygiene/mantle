#!/usr/bin/env bats
# Behavioral tests for bin/dlsite.

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

@test "dlsite --help exits 0 and prints usage" {
	run_bin dlsite --help
	assert_success
	assert_output_contains "Usage"
}

@test "dlsite --version exits 0 and prints a version" {
	run_bin dlsite --version
	assert_success
	assert_valid_version
}

@test "dlsite unknown option exits non-zero" {
	run_bin dlsite --no-such-flag
	assert_failure
}

@test "dlsite exits non-zero without a URL argument" {
	run_bin dlsite
	assert_failure
}

@test "dlsite exits non-zero when wget is unavailable" {
	make_stub "wget" 127 ""
	make_stub "curl" 127 ""
	run_bin dlsite https://example.com
	assert_failure
}
