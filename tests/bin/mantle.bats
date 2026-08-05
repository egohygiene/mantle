#!/usr/bin/env bats
# Behavioral tests for bin/mantle — the public command dispatcher.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

# ---------------------------------------------------------------------------
# Help and version
# ---------------------------------------------------------------------------

@test "mantle --help exits 0 and prints usage" {
	run_bin mantle --help
	assert_success
	assert_output_contains "Usage"
}

@test "mantle -h exits 0 and prints usage" {
	run_bin mantle -h
	assert_success
	assert_output_contains "Usage"
}

@test "mantle with no arguments exits 0 and prints usage" {
	run_bin mantle
	assert_success
	assert_output_contains "Usage"
}

@test "mantle --version exits 0 and prints a version" {
	run_bin mantle --version
	assert_success
	# mantle version may be a semver or a git-describe string; just check for digits.
	printf "%s\n" "${output}" | grep -q '[0-9]'
}

@test "mantle version subcommand exits 0 and prints a version" {
	run_bin mantle version
	assert_success
	printf "%s\n" "${output}" | grep -q '[0-9]'
}

# ---------------------------------------------------------------------------
# Unknown option
# ---------------------------------------------------------------------------

@test "mantle unknown option exits non-zero" {
	run_bin mantle --no-such-flag
	assert_failure
}

# ---------------------------------------------------------------------------
# Root resolution
# ---------------------------------------------------------------------------

@test "mantle resolves MANTLE_ROOT from its own location" {
	run_bin_with_env mantle "MANTLE_ROOT=" -- --version
	assert_success
}
