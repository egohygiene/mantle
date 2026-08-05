#!/usr/bin/env bats
# Behavioral tests for bin/ytdlp-channel.

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

@test "ytdlp-channel --help exits 0 and prints usage" {
	run_bin ytdlp-channel --help
	assert_success
	assert_output_contains "Usage"
}

@test "ytdlp-channel --version exits 0 and prints a version" {
	run_bin ytdlp-channel --version
	assert_success
	assert_valid_version
}

@test "ytdlp-channel unknown option exits non-zero" {
	run_bin ytdlp-channel --no-such-flag
	assert_failure
}

@test "ytdlp-channel exits non-zero without arguments" {
	run_bin ytdlp-channel
	assert_failure
}

@test "ytdlp-channel exits non-zero when yt-dlp is unavailable" {
	make_stub "yt-dlp" 127 ""
	run_bin ytdlp-channel https://youtube.com/c/something
	assert_failure
}
