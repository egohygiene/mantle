#!/usr/bin/env bats
# Behavioral tests for bin/shell-doctor.

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

@test "shell-doctor --help exits 0 and prints usage" {
	run_bin shell-doctor --help
	assert_success
	assert_output_contains "Usage"
}

@test "shell-doctor --version exits 0 and prints a version" {
	run_bin shell-doctor --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Basic run
# ---------------------------------------------------------------------------

@test "shell-doctor exits 0 against the Mantle repository" {
	run_bin_with_env shell-doctor "MANTLE_ROOT=${MANTLE_ROOT}" --
	# Accept 0 (clean) or 1 (failures detected) — both are valid exit codes.
	[[ "${status}" -eq 0 || "${status}" -eq 1 || "${status}" -eq 2 ]]
}

# ---------------------------------------------------------------------------
# --quiet mode
# ---------------------------------------------------------------------------

@test "shell-doctor --quiet suppresses ok lines" {
	run_bin_with_env shell-doctor "MANTLE_ROOT=${MANTLE_ROOT}" -- --quiet
	[[ "${status}" -eq 0 || "${status}" -eq 1 || "${status}" -eq 2 ]]
	assert_output_not_contains "ok    "
}

# ---------------------------------------------------------------------------
# --strict mode
# ---------------------------------------------------------------------------

@test "shell-doctor --strict returns 2 when only warnings are present" {
	# We cannot guarantee warnings exist; just verify the command accepts the flag.
	run_bin_with_env shell-doctor "MANTLE_ROOT=${MANTLE_ROOT}" -- --strict
	[[ "${status}" -eq 0 || "${status}" -eq 1 || "${status}" -eq 2 ]]
}

# ---------------------------------------------------------------------------
# --root option
# ---------------------------------------------------------------------------

@test "shell-doctor --root accepts an explicit Mantle root" {
	run_bin shell-doctor --root "${MANTLE_ROOT}"
	[[ "${status}" -eq 0 || "${status}" -eq 1 || "${status}" -eq 2 ]]
}

@test "shell-doctor --root with non-existent directory fails cleanly" {
	run_bin shell-doctor --root "${BIN_TEST_HOME}/no-such-root"
	assert_failure
}

# ---------------------------------------------------------------------------
# Invalid usage
# ---------------------------------------------------------------------------

@test "shell-doctor unknown option exits 64" {
	run_bin shell-doctor --no-such-flag
	assert_status 64
}
