#!/usr/bin/env bats
# Behavioral tests for bin/inject-subtitles.

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

@test "inject-subtitles --help exits 0 and prints usage" {
	run_bin inject-subtitles --help
	assert_success
	assert_output_contains "sage"
}

@test "inject-subtitles --version exits 0 and prints a version" {
	run_bin inject-subtitles --version
	assert_success
	assert_valid_version
}

@test "inject-subtitles unknown option exits non-zero" {
	run_bin inject-subtitles --no-such-flag
	assert_failure
}

@test "inject-subtitles exits non-zero without arguments" {
	run_bin inject-subtitles
	assert_failure
}

@test "inject-subtitles exits non-zero when ffmpeg is unavailable" {
	make_stub "ffmpeg" 127 ""
	run_bin inject-subtitles video.mp4 subs.srt
	assert_failure
}
