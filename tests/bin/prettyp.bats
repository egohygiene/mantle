#!/usr/bin/env bats
# Behavioral tests for bin/prettyp — JSON formatter.

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

# Require at least one JSON backend.
_require_json_backend() {
	if ! command -v jq >/dev/null 2>&1 &&
		! command -v python3 >/dev/null 2>&1 &&
		! command -v node >/dev/null 2>&1 &&
		! command -v ruby >/dev/null 2>&1; then
		skip "no JSON backend available (jq, python3, node, or ruby)"
	fi
}

# ---------------------------------------------------------------------------
# Help and version
# ---------------------------------------------------------------------------

@test "prettyp --help exits 0 and prints usage" {
	run_bin prettyp --help
	assert_success
	assert_output_contains "Usage"
}

@test "prettyp --version exits 0 and prints a version" {
	run_bin prettyp --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Valid JSON
# ---------------------------------------------------------------------------

@test "prettyp formats valid JSON from stdin" {
	_require_json_backend
	run bash -c "printf '%s' '{\"b\":2,\"a\":1}' | '${MANTLE_ROOT}/bin/prettyp'"
	assert_success
}

@test "prettyp formats valid JSON from a file" {
	_require_json_backend
	printf '%s\n' '{"key":"value"}' >"${WORK_DIR}/input.json"
	run_bin prettyp "${WORK_DIR}/input.json"
	assert_success
	assert_output_contains "key"
}

@test "prettyp --compact produces compact output" {
	_require_json_backend
	printf '%s\n' '{"a": 1}' >"${WORK_DIR}/input.json"
	run_bin prettyp --compact "${WORK_DIR}/input.json"
	assert_success
	# compact output should not have a newline inside the object
	assert_output_not_contains $'\n  '
}

# ---------------------------------------------------------------------------
# Invalid JSON
# ---------------------------------------------------------------------------

@test "prettyp exits 1 for invalid JSON input" {
	_require_json_backend
	run bash -c "printf '%s' 'not json' | '${MANTLE_ROOT}/bin/prettyp'"
	assert_status 1
}

# ---------------------------------------------------------------------------
# --output flag
# ---------------------------------------------------------------------------

@test "prettyp --output writes result to file" {
	_require_json_backend
	printf '%s\n' '{"x":1}' >"${WORK_DIR}/in.json"
	run_bin prettyp --output "${WORK_DIR}/out.json" "${WORK_DIR}/in.json"
	assert_success
	assert_file_exists "${WORK_DIR}/out.json"
}

# ---------------------------------------------------------------------------
# Backend selection
# ---------------------------------------------------------------------------

@test "prettyp --backend auto exits 0 for valid JSON" {
	_require_json_backend
	printf '%s\n' '{"a":1}' >"${WORK_DIR}/input.json"
	run_bin prettyp --backend auto "${WORK_DIR}/input.json"
	assert_success
}

# ---------------------------------------------------------------------------
# Invalid usage
# ---------------------------------------------------------------------------

@test "prettyp unknown option exits 2" {
	run_bin prettyp --no-such-flag
	assert_status 2
}

@test "prettyp exits 3 when no JSON backend is installed" {
	# This test is only meaningful on a system where no JSON backend is in PATH.
	# On systems with jq/python3/node/ruby in /usr/bin this test is skipped.
	if command -v jq >/dev/null 2>&1 ||
		command -v python3 >/dev/null 2>&1 ||
		command -v node >/dev/null 2>&1 ||
		command -v ruby >/dev/null 2>&1; then
		skip "a JSON backend is available system-wide; no-backend path cannot be exercised"
	fi
	printf '%s\n' '{"a":1}' >"${WORK_DIR}/input.json"
	run_bin prettyp "${WORK_DIR}/input.json"
	assert_status 3
}
