#!/usr/bin/env bats
# Behavioral tests for bin/gcloud-vm.

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

@test "gcloud-vm --help exits 0 and prints usage" {
	run_bin gcloud-vm --help
	assert_success
	assert_output_contains "Usage"
}

@test "gcloud-vm --version exits 0 and prints a version" {
	run_bin gcloud-vm --version
	assert_success
	assert_valid_version
}

@test "gcloud-vm unknown option exits non-zero" {
	run_bin gcloud-vm --no-such-flag
	assert_failure
}

@test "gcloud-vm exits non-zero when gcloud is unavailable" {
	make_stub "gcloud" 127 ""
	run_bin gcloud-vm list
	assert_failure
}
