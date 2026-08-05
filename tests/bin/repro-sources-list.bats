#!/usr/bin/env bats
# Behavioral tests for bin/repro-sources-list.

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

@test "repro-sources-list --help exits 0 and prints usage" {
	run_bin repro-sources-list --help
	assert_success
	assert_output_contains "Usage"
}

@test "repro-sources-list --version exits 0 and prints a version" {
	run_bin repro-sources-list --version
	assert_success
	assert_valid_version
}

@test "repro-sources-list unknown option exits non-zero" {
	run_bin repro-sources-list --no-such-flag
	assert_failure
}

@test "repro-sources-list requires root and fails without sudo" {
	make_stub "sudo" 1 ""
	run_bin repro-sources-list
	assert_failure
}
