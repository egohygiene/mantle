#!/usr/bin/env bats
# Behavioral tests for bin/apt-freeze, bin/apt-install, and bin/apt-base.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

# ===========================================================================
# apt-freeze
# ===========================================================================

@test "apt-freeze --help exits 0 and prints usage" {
	run_bin apt-freeze --help
	assert_success
	assert_output_contains "Usage"
}

@test "apt-freeze --version exits 0 and prints a version" {
	run_bin apt-freeze --version
	assert_success
	assert_valid_version
}

@test "apt-freeze unknown option exits non-zero" {
	run_bin apt-freeze --no-such-flag
	assert_failure
}

@test "apt-freeze requires root and fails without sudo or root" {
	# apt-freeze should exit non-zero when not running as root and sudo is absent.
	if [[ "${EUID}" -eq 0 ]]; then
		skip "root can run apt-freeze without sudo"
	fi
	make_stub "sudo" 1 ""
	run_bin apt-freeze
	assert_failure
}

# ===========================================================================
# apt-install
# ===========================================================================

@test "apt-install --help exits 0 and prints usage" {
	run_bin apt-install --help
	assert_success
	assert_output_contains "Usage"
}

@test "apt-install --version exits 0 and prints a version" {
	run_bin apt-install --version
	assert_success
	assert_valid_version
}

@test "apt-install unknown option exits non-zero" {
	run_bin apt-install --no-such-flag
	assert_failure
}

@test "apt-install requires root and fails without sudo or root" {
	make_stub "sudo" 1 ""
	run_bin apt-install curl
	assert_failure
}

# ===========================================================================
# apt-base
# ===========================================================================

@test "apt-base --help exits 0 and prints usage" {
	run_bin apt-base --help
	assert_success
	assert_output_contains "Usage"
}

@test "apt-base --version exits 0 and prints a version" {
	run_bin apt-base --version
	assert_success
	assert_valid_version
}

@test "apt-base requires root and fails without sudo or root" {
	make_stub "sudo" 1 ""
	run_bin apt-base
	assert_failure
}
