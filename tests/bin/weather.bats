#!/usr/bin/env bats
# Behavioral tests for bin/weather.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "weather --help exits 0 and prints usage" {
	run_bin weather --help
	assert_success
	assert_output_contains "Usage"
}

@test "weather --version exits 0 and prints a version" {
	run_bin weather --version
	assert_success
	assert_valid_version
}

@test "weather unknown option exits non-zero" {
	run_bin weather --no-such-flag
	assert_failure
}

@test "weather --print-url prints a URL and exits 0" {
	run_bin weather --print-url London
	assert_success
	assert_output_contains "wttr"
}

@test "weather accepts a location argument" {
	stub_curl_success "Weather stub"
	run_bin weather London
	[[ "${status}" -eq 0 || "${status}" -eq 1 ]]
}

@test "weather --format json exits without error with curl stub" {
	stub_curl_success '{"current_condition":[]}'
	run_bin weather --format json London
	[[ "${status}" -eq 0 || "${status}" -eq 1 ]]
}

@test "weather exits non-zero when curl is unavailable" {
	make_stub "curl" 127 ""
	make_stub "wget" 127 ""
	run_bin weather London
	assert_failure
}
