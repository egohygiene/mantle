#!/usr/bin/env bats
# Behavioral tests for bin/devcontainer-up.

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

@test "devcontainer-up --help exits 0 and prints usage" {
	run_bin devcontainer-up --help
	assert_success
	assert_output_contains "Usage"
}

@test "devcontainer-up --version exits 0 and prints a version" {
	run_bin devcontainer-up --version
	assert_success
	assert_valid_version
}

@test "devcontainer-up unknown option exits non-zero" {
	run_bin devcontainer-up --no-such-flag
	assert_failure
}

@test "devcontainer-up exits non-zero when devcontainer is unavailable" {
	make_stub "devcontainer" 127 ""
	run_bin devcontainer-up
	assert_failure
}
