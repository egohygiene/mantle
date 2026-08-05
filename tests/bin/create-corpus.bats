#!/usr/bin/env bats
# Behavioral tests for bin/create-corpus.

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

@test "create-corpus --help exits 0 and prints usage" {
	run_bin create-corpus --help
	assert_success
	assert_output_contains "Usage"
}

@test "create-corpus --version exits 0 and prints a version" {
	run_bin create-corpus --version
	assert_success
	assert_valid_version
}

@test "create-corpus unknown option exits non-zero" {
	run_bin create-corpus --no-such-flag
	assert_failure
}

@test "create-corpus exits non-zero without required arguments" {
	run_bin create-corpus
	assert_failure
}
