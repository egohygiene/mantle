#!/usr/bin/env bats
# Behavioral tests for bin/brightness.

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

@test "brightness --help exits 0 and prints usage" {
	run_bin brightness --help
	assert_success
	assert_output_contains "Usage"
}

@test "brightness --version exits 0 and prints a version" {
	run_bin brightness --version
	assert_success
	assert_valid_version
}

@test "brightness unknown option exits non-zero" {
	run_bin brightness --no-such-flag
	assert_failure
}

@test "brightness exits non-zero when no backend is available" {
	make_stub "brightnessctl" 127 ""
	make_stub "xrandr" 127 ""
	make_stub "ddcutil" 127 ""
	run_bin brightness 50
	assert_failure
}
