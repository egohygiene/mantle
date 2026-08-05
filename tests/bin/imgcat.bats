#!/usr/bin/env bats
# Behavioral tests for bin/imgcat.

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

@test "imgcat --help exits 0 and prints usage" {
	run_bin imgcat --help
	assert_success
	assert_output_contains "Usage"
}

@test "imgcat --version exits 0 and prints a version" {
	run_bin imgcat --version
	assert_success
	assert_valid_version
}

@test "imgcat unknown option exits non-zero" {
	run_bin imgcat --no-such-flag
	assert_failure
}

@test "imgcat exits non-zero without an input file" {
	run_bin imgcat
	assert_failure
}
