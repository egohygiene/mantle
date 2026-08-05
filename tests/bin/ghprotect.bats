#!/usr/bin/env bats
# Behavioral tests for bin/ghprotect.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "ghprotect --help exits 0 and prints usage" {
	run_bin ghprotect --help
	assert_success
	assert_output_contains "Usage"
}

@test "ghprotect --version exits 0 and prints a version" {
	run_bin ghprotect --version
	assert_success
	assert_valid_version
}

@test "ghprotect unknown option exits non-zero" {
	run_bin ghprotect --no-such-flag
	assert_failure
}

@test "ghprotect preview mode (no args) exits 0 without requiring gh" {
	run_bin ghprotect
	assert_success
}

@test "ghprotect --execute exits non-zero when gh is unavailable" {
	make_stub "gh" 127 ""
	run_bin ghprotect --execute owner/repo
	assert_failure
}
