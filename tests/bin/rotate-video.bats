#!/usr/bin/env bats
# Behavioral tests for bin/rotate-video.

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

@test "rotate-video --help exits 0 and prints usage" {
	run_bin rotate-video --help
	assert_success
	assert_output_contains "Usage"
}

@test "rotate-video --version exits 0 and prints a version" {
	run_bin rotate-video --version
	assert_success
	assert_valid_version
}

@test "rotate-video unknown option exits non-zero" {
	run_bin rotate-video --no-such-flag
	assert_failure
}

@test "rotate-video exits non-zero when ffmpeg is unavailable" {
	make_stub "ffmpeg" 127 ""
	run_bin rotate-video input.mp4
	assert_failure
}

@test "rotate-video requires an input file argument" {
	run_bin rotate-video
	assert_failure
}
