#!/usr/bin/env bats
# Behavioral tests for bin/uninstall-google-drive.

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

@test "uninstall-google-drive --help exits 0 and prints usage" {
	run_bin uninstall-google-drive --help
	assert_success
	assert_output_contains "Usage"
}

@test "uninstall-google-drive --version exits 0 and prints a version" {
	run_bin uninstall-google-drive --version
	assert_success
	assert_valid_version
}

@test "uninstall-google-drive unknown option exits non-zero" {
	run_bin uninstall-google-drive --no-such-flag
	assert_failure
}

@test "uninstall-google-drive refuses unsupported systems before discovery" {
	make_stub "uname" 0 "Linux"
	run_bin uninstall-google-drive scan
	assert_status 69
}
