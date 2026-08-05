#!/usr/bin/env bats
# Behavioral tests for bin/ghtemplates.

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

@test "ghtemplates --help exits 0 and prints usage" {
	run_bin ghtemplates --help
	assert_success
	assert_output_contains "Usage"
}

@test "ghtemplates --version exits 0 and prints a version" {
	run_bin ghtemplates --version
	assert_success
	assert_valid_version
}

@test "ghtemplates unknown option exits non-zero" {
	run_bin ghtemplates --no-such-flag
	assert_failure
}

@test "ghtemplates exits non-zero without arguments" {
	run_bin ghtemplates
	assert_failure
}

@test "ghtemplates exits non-zero when gh is unavailable" {
	make_stub "gh" 127 ""
	run_bin ghtemplates owner/repo
	assert_failure
}
