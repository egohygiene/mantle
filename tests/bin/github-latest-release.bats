#!/usr/bin/env bats
# Behavioral tests for bin/github-latest-release.

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

@test "github-latest-release --help exits 0 and prints usage" {
	run_bin github-latest-release --help
	assert_success
	assert_output_contains "Usage"
}

@test "github-latest-release --version exits 0 and prints a version" {
	run_bin github-latest-release --version
	assert_success
	assert_valid_version
}

@test "github-latest-release unknown option exits non-zero" {
	run_bin github-latest-release --no-such-flag
	assert_failure
}

@test "github-latest-release exits non-zero without arguments" {
	run_bin github-latest-release
	assert_failure
}

@test "github-latest-release exits non-zero when gh is unavailable" {
	make_stub "gh" 127 ""
	run_bin github-latest-release owner/repo
	assert_failure
}
