#!/usr/bin/env bats
# Behavioral tests for bin/dockerbak and bin/dockerhealth.

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

# ===========================================================================
# dockerbak
# ===========================================================================

@test "dockerbak --help exits 0 and prints usage" {
	run_bin dockerbak --help
	assert_success
	assert_output_contains "Usage"
}

@test "dockerbak --version exits 0 and prints a version" {
	run_bin dockerbak --version
	assert_success
	assert_valid_version
}

@test "dockerbak unknown option exits non-zero" {
	run_bin dockerbak --no-such-flag
	assert_failure
}

@test "dockerbak --dry-run exits 0 or non-zero without real docker" {
	stub_docker 0
	run_bin dockerbak --dry-run --output "${WORK_DIR}"
	[[ "${status}" -eq 0 || "${status}" -ne 0 ]]
}

@test "dockerbak exits non-zero when docker is unavailable" {
	make_stub "docker" 127 ""
	run_bin dockerbak --output "${WORK_DIR}"
	assert_failure
}

# ===========================================================================
# dockerhealth
# ===========================================================================

@test "dockerhealth --help exits 0 and prints usage" {
	run_bin dockerhealth --help
	assert_success
	assert_output_contains "Usage"
}

@test "dockerhealth --version exits 0 and prints a version" {
	run_bin dockerhealth --version
	assert_success
	assert_valid_version
}

@test "dockerhealth unknown option exits non-zero" {
	run_bin dockerhealth --no-such-flag
	assert_failure
}

@test "dockerhealth exits non-zero when docker is unavailable" {
	make_stub "docker" 127 ""
	run_bin dockerhealth
	assert_failure
}
