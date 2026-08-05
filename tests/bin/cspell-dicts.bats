#!/usr/bin/env bats
# Behavioral tests for bin/cspell-dicts.

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

@test "cspell-dicts --help exits 0 and prints usage" {
	run_bin cspell-dicts --help
	assert_success
	assert_output_contains "sage"
}

@test "cspell-dicts --version exits 0 and prints a version" {
	run_bin cspell-dicts --version
	assert_success
	assert_valid_version
}

@test "cspell-dicts unknown option exits non-zero" {
	run_bin cspell-dicts --no-such-flag
	assert_failure
}

@test "cspell-dicts exits non-zero when cspell is unavailable" {
	make_stub "cspell" 127 ""
	make_stub "npx" 127 ""
	run_bin cspell-dicts
	assert_failure
}
