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

@test "inject-subtitles without arguments succeeds without writing when its working directory has no matches" {
	stub_ffmpeg
	make_recording_stub ffprobe 0 ""
	cd "${WORK_DIR}"
	run_bin inject-subtitles
	assert_success
	assert_output_contains "No matching video/subtitle pairs found in ${WORK_DIR}"
	[[ "$(recording_stub_calls ffmpeg)" == 0 ]]
	[[ "$(recording_stub_calls ffprobe)" == 0 ]]
	[[ -z "$(find "${WORK_DIR}" -mindepth 1 -print)" ]]
}

@test "inject-subtitles rejects a missing scan directory without creating it" {
	stub_ffmpeg
	make_recording_stub ffprobe 0 ""
	local missing_directory="${WORK_DIR}/missing"
	run_bin inject-subtitles --directory "${missing_directory}"
	assert_status 1
	assert_output_contains "scan directory does not exist: ${missing_directory}"
	[[ ! -e "${missing_directory}" ]]
	[[ "$(recording_stub_calls ffmpeg)" == 0 ]]
	[[ "$(recording_stub_calls ffprobe)" == 0 ]]
}

@test "inject-subtitles exits non-zero when ffmpeg is unavailable" {
	make_stub "ffmpeg" 127 ""
	run_bin inject-subtitles video.mp4 subs.srt
	assert_failure
}
