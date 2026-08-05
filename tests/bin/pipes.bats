#!/usr/bin/env bats
# Behavioral tests for bin/pipes — terminal pipe screensaver.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "pipes --help exits 0 and prints usage" {
	run_bin pipes --help
	assert_success
	assert_output_contains "Usage"
}

@test "pipes --version exits 0 and prints a version" {
	run_bin pipes --version
	assert_success
	assert_valid_version
}
