#!/usr/bin/env bats
# Behavioral tests for bin/ffmpeg-loop.

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

@test "ffmpeg-loop --help exits 0 and prints usage" {
	run_bin ffmpeg-loop --help
	assert_success
	assert_output_contains "Usage"
}

@test "ffmpeg-loop --version exits 0 and prints a version" {
	run_bin ffmpeg-loop --version
	assert_success
	assert_valid_version
}

@test "ffmpeg-loop unknown option exits non-zero" {
	run_bin ffmpeg-loop --no-such-flag
	assert_failure
}

@test "ffmpeg-loop exits non-zero when ffmpeg is unavailable" {
	make_stub "ffmpeg" 127 ""
	run_bin ffmpeg-loop input.mp4
	assert_failure
}

@test "ffmpeg-loop requires an input file argument" {
	run_bin ffmpeg-loop
	assert_failure
}
