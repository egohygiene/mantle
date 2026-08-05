#!/usr/bin/env bats
# Behavioral tests for bin/github-issues.

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

@test "github-issues --help exits 0 and prints usage" {
	run_bin github-issues --help
	assert_success
	assert_output_contains "Usage"
}

@test "github-issues --version exits 0 and prints a version" {
	run_bin github-issues --version
	assert_success
	assert_valid_version
}

@test "github-issues unknown option exits non-zero" {
	run_bin github-issues --no-such-flag
	assert_failure
}

@test "github-issues exits non-zero without arguments" {
	run_bin github-issues
	assert_failure
}

@test "github-issues exits non-zero when gh is unavailable" {
	make_stub "gh" 127 ""
	run_bin github-issues owner/repo
	assert_failure
}
