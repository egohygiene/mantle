#!/usr/bin/env bats
# Behavioral tests for bin/dlpage.

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

@test "dlpage --help exits 0 and prints usage" {
	run_bin dlpage --help
	assert_success
	assert_output_contains "Usage"
}

@test "dlpage --version exits 0 and prints a version" {
	run_bin dlpage --version
	assert_success
	assert_valid_version
}

@test "dlpage unknown option exits non-zero" {
	run_bin dlpage --no-such-flag
	assert_failure
}

@test "dlpage exits non-zero without a URL argument" {
	run_bin dlpage
	assert_failure
}

@test "dlpage exits non-zero when curl is unavailable" {
	make_stub "curl" 127 ""
	make_stub "wget" 127 ""
	run_bin dlpage https://example.com
	assert_failure
}
