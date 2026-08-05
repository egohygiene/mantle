#!/usr/bin/env bats
# Behavioral tests for bin/generate-pwa-icons.

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

@test "generate-pwa-icons --help exits 0 and prints usage" {
	run_bin generate-pwa-icons --help
	assert_success
	assert_output_contains "Usage"
}

@test "generate-pwa-icons --version exits 0 and prints a version" {
	run_bin generate-pwa-icons --version
	assert_success
	assert_valid_version
}

@test "generate-pwa-icons unknown option exits non-zero" {
	run_bin generate-pwa-icons --no-such-flag
	assert_failure
}

@test "generate-pwa-icons exits non-zero when ImageMagick is unavailable" {
	make_stub "convert" 127 ""
	make_stub "magick" 127 ""
	run_bin generate-pwa-icons input.png
	assert_failure
}

@test "generate-pwa-icons requires an input file argument" {
	run_bin generate-pwa-icons
	assert_failure
}
