#!/usr/bin/env bats
# Behavioral tests for bin/sysinfo.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "sysinfo --help exits 0 and prints usage" {
	run_bin sysinfo --help
	assert_success
	assert_output_contains "Usage"
}

@test "sysinfo --version exits 0 and prints a version" {
	run_bin sysinfo --version
	assert_success
	assert_valid_version
}

@test "sysinfo unknown option exits non-zero" {
	run_bin sysinfo --no-such-flag
	assert_failure
}

@test "sysinfo exits 0 and produces nonempty output" {
	run_bin sysinfo
	assert_success
	[[ -n "${output}" ]]
}

@test "sysinfo --no-color exits 0" {
	run_bin sysinfo --no-color
	assert_success
}

@test "sysinfo --include-network exits 0" {
	run_bin sysinfo --include-network
	assert_success
}

@test "sysinfo --include-environment redacts sensitive variables" {
	run_bin_with_env sysinfo "MY_PASSWORD=secret123" -- --include-environment
	assert_success
	assert_output_not_contains "secret123"
}

@test "sysinfo --all exits 0" {
	run_bin sysinfo --all
	assert_success
}
