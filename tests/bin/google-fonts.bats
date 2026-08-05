#!/usr/bin/env bats
# Behavioral tests for bin/google-fonts.

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

@test "google-fonts --help exits 0 and prints usage" {
	run_bin google-fonts --help
	assert_success
	assert_output_contains "Usage"
}

@test "google-fonts --version exits 0 and prints a version" {
	run_bin google-fonts --version
	assert_success
	assert_valid_version
}

@test "google-fonts unknown option exits non-zero" {
	run_bin google-fonts --no-such-flag
	assert_failure
}

@test "google-fonts exits non-zero when wget/curl is unavailable" {
	make_stub "wget" 127 ""
	make_stub "curl" 127 ""
	run_bin google-fonts "Roboto"
	assert_failure
}

@test "google-fonts requires a font name argument" {
	run_bin google-fonts
	assert_failure
}
