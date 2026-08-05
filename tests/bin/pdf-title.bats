#!/usr/bin/env bats
# Behavioral tests for bin/pdf-title.

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

@test "pdf-title --help exits 0 and prints usage" {
	run_bin pdf-title --help
	assert_success
	assert_output_contains "sage"
}

@test "pdf-title --version exits 0 and prints a version" {
	run_bin pdf-title --version
	assert_success
	assert_valid_version
}

@test "pdf-title unknown option exits non-zero" {
	run_bin pdf-title --no-such-flag
	assert_failure
}

@test "pdf-title exits non-zero without arguments" {
	run_bin pdf-title
	assert_failure
}

@test "pdf-title exits non-zero when pymupdf is unavailable" {
	make_stub "python3" 127 ""
	run_bin pdf-title file.pdf
	assert_failure
}
