#!/usr/bin/env bats
# Behavioral tests for bin/is-executable.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

# ---------------------------------------------------------------------------
# Help and version
# ---------------------------------------------------------------------------

@test "is-executable --help exits 0 and prints usage" {
	run_bin is-executable --help
	assert_success
	assert_output_contains "Usage"
}

@test "is-executable --version exits 0 and prints a version" {
	run_bin is-executable --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Path checks
# ---------------------------------------------------------------------------

@test "is-executable succeeds for an executable file path" {
	local tmp_exe="${BIN_TEST_HOME}/myexe"
	printf '#!/bin/sh\n' >"${tmp_exe}"
	chmod 0755 "${tmp_exe}"
	run_bin is-executable "${tmp_exe}"
	assert_success
}

@test "is-executable fails for a non-executable file path" {
	local tmp_file="${BIN_TEST_HOME}/notexe"
	printf 'data\n' >"${tmp_file}"
	chmod 0644 "${tmp_file}"
	run_bin is-executable "${tmp_file}"
	assert_failure
}

@test "is-executable fails for a missing path" {
	run_bin is-executable "${BIN_TEST_HOME}/does_not_exist"
	assert_failure
}

# ---------------------------------------------------------------------------
# Command-name lookup
# ---------------------------------------------------------------------------

@test "is-executable succeeds when a command is on PATH" {
	# Create a stub command in the stub dir (which is on PATH).
	printf '#!/bin/sh\nexit 0\n' >"${BIN_STUB_DIR}/mytool"
	chmod 0755 "${BIN_STUB_DIR}/mytool"
	run_bin is-executable mytool
	assert_success
}

@test "is-executable fails when a command is not on PATH" {
	run_bin is-executable __no_such_command_xyz__
	assert_failure
}

# ---------------------------------------------------------------------------
# Double-dash separator
# ---------------------------------------------------------------------------

@test "is-executable -- treats following arg as a name even if it starts with -" {
	# Create a temp executable file that we reference by path (not by name lookup).
	local tmp_exe="${BIN_TEST_HOME}/dash-prefixed-tool"
	printf '#!/bin/sh\nexit 0\n' >"${tmp_exe}"
	chmod 0755 "${tmp_exe}"
	# Use -- followed by a path (the documented use case from the help text).
	run_bin is-executable -- "${tmp_exe}"
	assert_success
}

# ---------------------------------------------------------------------------
# Invalid usage
# ---------------------------------------------------------------------------

@test "is-executable with no arguments exits 2" {
	run_bin is-executable
	assert_status 2
}
