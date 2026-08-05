#!/usr/bin/env bats
# Behavioral tests for bin/convert-to-mp4.

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

@test "convert-to-mp4 --help exits 0 and prints usage" {
	run_bin convert-to-mp4 --help
	assert_success
	assert_output_contains "Usage"
}

@test "convert-to-mp4 --version exits 0 and prints a version" {
	run_bin convert-to-mp4 --version
	assert_success
	assert_valid_version
}

@test "convert-to-mp4 unknown option exits non-zero" {
	run_bin convert-to-mp4 --no-such-flag
	assert_failure
}

@test "convert-to-mp4 exits non-zero when ffmpeg is unavailable" {
	make_stub "ffmpeg" 127 ""
	run_bin convert-to-mp4 input.mkv
	assert_failure
}

@test "convert-to-mp4 requires an input file argument" {
	run_bin convert-to-mp4
	assert_failure
}
