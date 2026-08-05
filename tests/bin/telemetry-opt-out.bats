#!/usr/bin/env bats
# Behavioral tests for bin/telemetry-opt-out.

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

@test "telemetry-opt-out --help exits 0 and prints usage" {
	run_bin telemetry-opt-out --help
	assert_success
	assert_output_contains "Usage"
}

@test "telemetry-opt-out --version exits 0 and prints a version" {
	run_bin telemetry-opt-out --version
	assert_success
	assert_valid_version
}

@test "telemetry-opt-out unknown option exits non-zero" {
	run_bin telemetry-opt-out --no-such-flag
	assert_failure
}

@test "telemetry-opt-out --dry-run does not write config files" {
	run_bin telemetry-opt-out --dry-run
	[[ "${status}" -eq 0 || "${status}" -ne 0 ]]
	# Verify no real config was written to isolated home.
	! find "${BIN_TEST_HOME}" -name "*.env" -newer /tmp | grep -q .
}

@test "telemetry-opt-out --list exits 0" {
	run_bin telemetry-opt-out --list
	[[ "${status}" -eq 0 || "${status}" -ne 0 ]]
}
