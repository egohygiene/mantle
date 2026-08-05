#!/usr/bin/env bats
# Behavioral tests for bin/apt-freeze, bin/apt-install, and bin/install-apt-base.

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
# install-apt-base
# ===========================================================================

@test "install-apt-base --help exits 0 and prints usage" {
	run_bin install-apt-base --help
	assert_success
	assert_output_contains "Usage"
}

@test "install-apt-base --version exits 0 and prints a version" {
	run_bin install-apt-base --version
	assert_success
	assert_valid_version
}

@test "install-apt-base requires root and fails without sudo or root" {
	make_stub "sudo" 1 ""
	run_bin install-apt-base
	assert_failure
}
