#!/usr/bin/env bats
# Behavioral tests for bin/extract-frames.

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

@test "extract-frames --help exits 0 and prints usage" {
	run_bin extract-frames --help
	assert_success
	assert_output_contains "Usage"
}

@test "extract-frames --version exits 0 and prints a version" {
	run_bin extract-frames --version
	assert_success
	assert_valid_version
}

@test "extract-frames unknown option exits non-zero" {
	run_bin extract-frames --no-such-flag
	assert_failure
}

@test "extract-frames exits non-zero when ffmpeg is unavailable" {
	make_stub "ffmpeg" 127 ""
	run_bin extract-frames input.mp4
	assert_failure
}

@test "extract-frames requires an input file argument" {
	run_bin extract-frames
	assert_failure
}
