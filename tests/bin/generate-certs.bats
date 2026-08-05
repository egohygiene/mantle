#!/usr/bin/env bats
# Behavioral tests for bin/generate-certs.

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

@test "generate-certs --help exits 0 and prints usage" {
	run_bin generate-certs --help
	assert_success
	assert_output_contains "Usage"
}

@test "generate-certs --version exits 0 and prints a version" {
	run_bin generate-certs --version
	assert_success
	assert_valid_version
}

@test "generate-certs unknown option exits non-zero" {
	run_bin generate-certs --no-such-flag
	assert_failure
}

@test "generate-certs exits non-zero when openssl is unavailable" {
	make_stub "openssl" 127 ""
	run_bin generate-certs
	assert_failure
}
