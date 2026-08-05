#!/usr/bin/env bats
# Behavioral tests for bin/phone-harvest.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "phone-harvest --help exits 0 and prints usage" {
	run_bin phone-harvest --help
	assert_success
	# phone-harvest uses its own help format with "USAGE" header.
	assert_output_contains "SAGE"
}

@test "phone-harvest --version exits 0 and prints a version" {
	run_bin phone-harvest --version
	assert_success
	assert_valid_version
}

@test "phone-harvest unknown option exits non-zero" {
	run_bin phone-harvest --no-such-flag
	assert_failure
}

@test "phone-harvest exits non-zero when ssh is unavailable" {
	make_stub "ssh" 127 ""
	make_stub "rsync" 127 ""
	run_bin phone-harvest
	assert_failure
}
