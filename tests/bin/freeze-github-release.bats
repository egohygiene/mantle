#!/usr/bin/env bats
# Behavioral tests for bin/freeze-github-release.

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

@test "freeze-github-release --help exits 0 and prints usage" {
	run_bin freeze-github-release --help
	assert_success
	assert_output_contains "Usage"
}

@test "freeze-github-release --version exits 0 and prints a version" {
	run_bin freeze-github-release --version
	assert_success
	assert_valid_version
}

@test "freeze-github-release unknown option exits non-zero" {
	run_bin freeze-github-release --no-such-flag
	assert_failure
}

@test "freeze-github-release exits non-zero without arguments" {
	run_bin freeze-github-release
	assert_failure
}

@test "freeze-github-release --dry-run exits non-zero without gh" {
	make_stub "gh" 127 ""
	run_bin freeze-github-release --dry-run owner/repo
	assert_failure
}
