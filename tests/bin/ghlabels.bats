#!/usr/bin/env bats
# Behavioral tests for bin/ghlabels.

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

@test "ghlabels --help exits 0 and prints usage" {
	run_bin ghlabels --help
	assert_success
	assert_output_contains "Usage"
}

@test "ghlabels --version exits 0 and prints a version" {
	run_bin ghlabels --version
	assert_success
	assert_valid_version
}

@test "ghlabels unknown option exits non-zero" {
	run_bin ghlabels --no-such-flag
	assert_failure
}

@test "ghlabels exits non-zero without arguments" {
	run_bin ghlabels
	assert_failure
}

@test "ghlabels exits non-zero when gh is unavailable" {
	make_stub "gh" 127 ""
	run_bin ghlabels owner/repo
	assert_failure
}
