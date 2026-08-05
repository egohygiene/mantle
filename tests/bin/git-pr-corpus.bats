#!/usr/bin/env bats
# Behavioral tests for bin/git-pr-corpus.

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

@test "git-pr-corpus --help exits 0 and prints usage" {
	run_bin git-pr-corpus --help
	assert_success
	assert_output_contains "Usage"
}

@test "git-pr-corpus --version exits 0 and prints a version" {
	run_bin git-pr-corpus --version
	assert_success
	assert_valid_version
}

@test "git-pr-corpus unknown option exits non-zero" {
	run_bin git-pr-corpus --no-such-flag
	assert_failure
}

@test "git-pr-corpus exits non-zero without arguments" {
	run_bin git-pr-corpus
	assert_failure
}
