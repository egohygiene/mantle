#!/usr/bin/env bats
# Behavioral tests for bin/capitalize-folders.

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

@test "capitalize-folders --help exits 0 and prints usage" {
	run_bin capitalize-folders --help
	assert_success
	assert_output_contains "Usage"
}

@test "capitalize-folders --version exits 0 and prints a version" {
	run_bin capitalize-folders --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Dry-run — no filesystem changes
# ---------------------------------------------------------------------------

@test "capitalize-folders --dry-run does not rename directories" {
	mkdir -p "${WORK_DIR}/hello world"
	run_bin capitalize-folders --dry-run "${WORK_DIR}"
	assert_success
	# Original name must still exist
	[[ -d "${WORK_DIR}/hello world" ]]
	# Proposed new name must not exist
	[[ ! -d "${WORK_DIR}/Hello World" ]]
}

@test "capitalize-folders --dry-run prints proposed renames" {
	mkdir -p "${WORK_DIR}/api-clients"
	run_bin capitalize-folders --dry-run "${WORK_DIR}"
	assert_success
	assert_output_contains "Api-Clients"
}

# ---------------------------------------------------------------------------
# Actual rename
# ---------------------------------------------------------------------------

@test "capitalize-folders renames directory with single word" {
	mkdir -p "${WORK_DIR}/hello"
	run_bin capitalize-folders "${WORK_DIR}"
	assert_success
	[[ -d "${WORK_DIR}/Hello" ]]
	[[ ! -d "${WORK_DIR}/hello" ]]
}

@test "capitalize-folders renames directory with multiple words" {
	mkdir -p "${WORK_DIR}/hello world"
	run_bin capitalize-folders "${WORK_DIR}"
	assert_success
	[[ -d "${WORK_DIR}/Hello World" ]]
}

@test "capitalize-folders renames hyphenated directory" {
	mkdir -p "${WORK_DIR}/api-clients"
	run_bin capitalize-folders "${WORK_DIR}"
	assert_success
	[[ -d "${WORK_DIR}/Api-Clients" ]]
}

# ---------------------------------------------------------------------------
# --lowercase-rest
# ---------------------------------------------------------------------------

@test "capitalize-folders --lowercase-rest lowercases non-initial letters" {
	mkdir -p "${WORK_DIR}/hELLO wORLD"
	run_bin capitalize-folders --lowercase-rest "${WORK_DIR}"
	assert_success
	[[ -d "${WORK_DIR}/Hello World" ]]
}

# ---------------------------------------------------------------------------
# --include-hidden
# ---------------------------------------------------------------------------

@test "capitalize-folders skips hidden directories by default" {
	mkdir -p "${WORK_DIR}/.hidden"
	run_bin capitalize-folders "${WORK_DIR}"
	assert_success
	[[ -d "${WORK_DIR}/.hidden" ]]
}

@test "capitalize-folders --include-hidden processes hidden directories" {
	mkdir -p "${WORK_DIR}/.hidden"
	run_bin capitalize-folders --include-hidden --dry-run "${WORK_DIR}"
	assert_success
	assert_output_contains ".Hidden"
}

# ---------------------------------------------------------------------------
# --recursive
# ---------------------------------------------------------------------------

@test "capitalize-folders --recursive processes nested directories" {
	mkdir -p "${WORK_DIR}/parent/child subdir"
	run_bin capitalize-folders --recursive "${WORK_DIR}"
	assert_success
	[[ -d "${WORK_DIR}/Parent" ]]
}

# ---------------------------------------------------------------------------
# Empty directory
# ---------------------------------------------------------------------------

@test "capitalize-folders on empty directory exits 0" {
	run_bin capitalize-folders "${WORK_DIR}"
	assert_success
}

# ---------------------------------------------------------------------------
# Path with spaces
# ---------------------------------------------------------------------------

@test "capitalize-folders handles directory path containing spaces" {
	local spacedir="${BIN_TEST_HOME}/my work dir"
	mkdir -p "${spacedir}/sub dir"
	run_bin capitalize-folders "${spacedir}"
	assert_success
	[[ -d "${spacedir}/Sub Dir" ]]
}

# ---------------------------------------------------------------------------
# Invalid usage
# ---------------------------------------------------------------------------

@test "capitalize-folders unknown option exits non-zero" {
	run_bin capitalize-folders --no-such-flag
	assert_failure
}
