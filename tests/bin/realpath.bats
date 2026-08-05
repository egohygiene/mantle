#!/usr/bin/env bats
# Behavioral tests for bin/realpath.

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

# ---------------------------------------------------------------------------
# Help and version
# ---------------------------------------------------------------------------

@test "realpath --help exits 0 and prints usage" {
	run_bin realpath --help
	assert_success
	assert_output_contains "Usage"
}

@test "realpath --version exits 0 and prints a version" {
	run_bin realpath --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Existing path
# ---------------------------------------------------------------------------

@test "realpath resolves an existing file to its absolute path" {
	local file="${WORK_DIR}/myfile.txt"
	printf "content\n" >"${file}"
	run_bin realpath "${file}"
	assert_success
	assert_output_contains "${WORK_DIR}"
}

@test "realpath resolves an existing directory" {
	run_bin realpath "${WORK_DIR}"
	assert_success
	assert_output_contains "${WORK_DIR}"
}

# ---------------------------------------------------------------------------
# Relative path
# ---------------------------------------------------------------------------

@test "realpath resolves a relative path" {
	local file="${WORK_DIR}/rel.txt"
	printf "x\n" >"${file}"
	run bash -c "cd '${WORK_DIR}' && '${MANTLE_ROOT}/bin/realpath' rel.txt"
	assert_success
	assert_output_contains "${WORK_DIR}/rel.txt"
}

# ---------------------------------------------------------------------------
# Path with spaces
# ---------------------------------------------------------------------------

@test "realpath handles path with spaces" {
	local file="${WORK_DIR}/my file.txt"
	printf "x\n" >"${file}"
	run_bin realpath "${file}"
	assert_success
	assert_output_contains "my file.txt"
}

# ---------------------------------------------------------------------------
# Invalid usage
# ---------------------------------------------------------------------------

@test "realpath unknown option exits non-zero" {
	run_bin realpath --no-such-flag
	assert_failure
}

@test "realpath with no arguments exits non-zero" {
	run_bin realpath
	assert_failure
}
