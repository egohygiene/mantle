#!/usr/bin/env bats
# Behavioral tests for bin/makepng.

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

@test "makepng --help exits 0 and prints usage" {
	run_bin makepng --help
	assert_success
	assert_output_contains "Usage"
}

@test "makepng --version exits 0 and prints a version" {
	run_bin makepng --version
	assert_success
	assert_valid_version
}

@test "makepng unknown option exits non-zero" {
	run_bin makepng --no-such-flag
	assert_failure
}

@test "makepng exits non-zero when ImageMagick is unavailable" {
	make_stub "convert" 127 ""
	make_stub "magick" 127 ""
	run_bin makepng
	assert_failure
}
