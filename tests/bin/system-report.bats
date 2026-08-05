#!/usr/bin/env bats
# Behavioral tests for bin/system-report.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
	WORK_DIR="${BIN_TEST_HOME}/work"
	mkdir -p "${WORK_DIR}"
}

teardown() {
	bin_test_teardown
}

@test "system-report --help exits 0 and prints usage" {
	run_bin system-report --help
	assert_success
	assert_output_contains "Usage"
}

@test "system-report --version exits 0 and prints a version" {
	run_bin system-report --version
	assert_success
	assert_valid_version
}

@test "system-report unknown option exits non-zero" {
	run_bin system-report --no-such-flag
	assert_failure
}

@test "system-report exits 0 and produces nonempty output" {
	# system-report writes to a default file, so use --stdout to avoid clobber.
	run_bin system-report --stdout
	assert_success
	[[ -n "${output}" ]]
}

@test "system-report --output writes to a file" {
	local outfile="${WORK_DIR}/report.md"
	run_bin system-report --output "${outfile}"
	assert_success
	assert_file_exists "${outfile}"
}
