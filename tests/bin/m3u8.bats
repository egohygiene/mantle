#!/usr/bin/env bats
# Behavioral tests for bin/m3u8.

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

@test "m3u8 --help exits 0 and prints usage" {
	run_bin m3u8 --help
	assert_success
	assert_output_contains "sage"
}

@test "m3u8 --version exits 0 and prints a version" {
	run_bin m3u8 --version
	assert_success
	assert_valid_version
}

@test "m3u8 unknown option exits non-zero" {
	run_bin m3u8 --no-such-flag
	assert_failure
}

@test "m3u8 exits non-zero without arguments" {
	run_bin m3u8
	assert_failure
}

@test "m3u8 exits non-zero when ffmpeg is unavailable" {
	make_stub "ffmpeg" 127 ""
	run_bin m3u8 https://example.com/stream.m3u8
	assert_failure
}
