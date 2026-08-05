#!/usr/bin/env bats
# Behavioral tests for bin/vpn-toggle.

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

@test "vpn-toggle --help exits 0 and prints usage" {
	run_bin vpn-toggle --help
	assert_success
	assert_output_contains "Usage"
}

@test "vpn-toggle --version exits 0 and prints a version" {
	run_bin vpn-toggle --version
	assert_success
	assert_valid_version
}

@test "vpn-toggle unknown option exits non-zero" {
	run_bin vpn-toggle --no-such-flag
	assert_failure
}

@test "vpn-toggle exits non-zero when no VPN backend is available" {
	make_stub "nmcli" 127 ""
	make_stub "openvpn" 127 ""
	make_stub "wg" 127 ""
	run_bin vpn-toggle
	assert_failure
}
