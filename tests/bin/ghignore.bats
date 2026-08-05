#!/usr/bin/env bats
# Behavioral tests for bin/ghignore.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "ghignore --help exits 0 and prints usage" {
	run_bin ghignore --help
	assert_success
	assert_output_contains "Usage"
}

@test "ghignore --version exits 0 and prints a version" {
	run_bin ghignore --version
	assert_success
	assert_valid_version
}

@test "ghignore unknown option exits non-zero" {
	run_bin ghignore --no-such-flag
	assert_failure
}

@test "ghignore exits non-zero when curl is unavailable" {
	make_stub "curl" 127 ""
	run_bin ghignore
	assert_failure
}

@test "ghignore exits non-zero when jq and python3 are unavailable" {
	if ! command -v curl >/dev/null 2>&1; then skip "curl not available"; fi
	stub_curl_success '[{"name":"Python.gitignore"}]'
	make_stub "jq" 127 ""
	make_stub "python3" 127 ""
	run_bin ghignore
	assert_failure
}
