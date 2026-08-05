#!/usr/bin/env bats
# Behavioral tests for bin/convert-to-ico.

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

@test "convert-to-ico --help exits 0 and prints usage" {
	run_bin convert-to-ico --help
	assert_success
	assert_output_contains "Usage"
}

@test "convert-to-ico --version exits 0 and prints a version" {
	run_bin convert-to-ico --version
	assert_success
	assert_valid_version
}

@test "convert-to-ico unknown option exits non-zero" {
	run_bin convert-to-ico --no-such-flag
	assert_failure
}

@test "convert-to-ico exits non-zero when ImageMagick is unavailable" {
	make_stub "convert" 127 ""
	make_stub "magick" 127 ""
	run_bin convert-to-ico input.png
	assert_failure
}

@test "convert-to-ico requires an input file argument" {
	make_stub "convert" 0 ""
	run_bin convert-to-ico
	assert_failure
}
