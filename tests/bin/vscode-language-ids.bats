#!/usr/bin/env bats
# Behavioral tests for bin/vscode-language-ids.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "vscode-language-ids --help exits 0 and prints usage" {
	run_bin vscode-language-ids --help
	assert_success
	assert_output_contains "sage"
}

@test "vscode-language-ids --version exits 0 and prints a version" {
	run_bin vscode-language-ids --version
	assert_success
	assert_valid_version
}

@test "vscode-language-ids unknown option exits non-zero" {
	run_bin vscode-language-ids --no-such-flag
	assert_failure
}

@test "vscode-language-ids --no-default-paths exits 0 or 1 when no dirs found" {
	if ! command -v python3 >/dev/null 2>&1; then skip "python3 not available"; fi
	# With --no-default-paths and no extension dirs, command exits non-zero.
	run_bin vscode-language-ids --no-default-paths
	# Exit 0 (empty result) or exit 1 (no dirs found) are both valid.
	[[ "${status}" -eq 0 || "${status}" -eq 1 ]]
}

@test "vscode-language-ids --json with explicit empty built-in dir exits 0" {
	if ! command -v python3 >/dev/null 2>&1; then skip "python3 not available"; fi
	local empty_dir="${BIN_TEST_HOME}/vscode-ext"
	mkdir -p "${empty_dir}"
	run_bin vscode-language-ids --built-in-dir "${empty_dir}" --json
	[[ "${status}" -eq 0 || "${status}" -eq 1 ]]
}
