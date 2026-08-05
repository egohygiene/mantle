#!/usr/bin/env bats
# Behavioral tests for bin/cb — clipboard copy utility.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "cb --help exits 0 and prints usage" {
	run_bin cb --help
	assert_success
	assert_output_contains "Usage"
}

@test "cb --version exits 0 and prints a version" {
	run_bin cb --version
	assert_success
	assert_valid_version
}

@test "cb unknown option exits 64" {
	run_bin cb --no-such-flag
	assert_status 64
}

@test "cb --print-backend exits 0 or 69 (reports selected or missing backend)" {
	run_bin cb --print-backend
	[[ "${status}" -eq 0 || "${status}" -eq 69 ]]
}

@test "cb with pbcopy stub copies inline text" {
	stub_pbcopy
	run_bin_with_env cb "CB_BACKEND=pbcopy" -- hello world
	assert_success
	[[ "$(recording_stub_calls pbcopy)" -ge 1 ]]
}

@test "cb with wl-copy stub copies inline text" {
	stub_wl_copy
	run_bin_with_env cb "CB_BACKEND=wl-copy" -- hello world
	assert_success
}

@test "cb with xclip stub copies inline text" {
	stub_xclip
	run_bin_with_env cb "CB_BACKEND=xclip" -- hello world
	assert_success
}

@test "cb --file copies file content with pbcopy stub" {
	stub_pbcopy
	local tmpfile="${BIN_TEST_HOME}/secret.txt"
	printf "secret content\n" >"${tmpfile}"
	run_bin_with_env cb "CB_BACKEND=pbcopy" -- --file "${tmpfile}"
	assert_success
}

@test "cb --file with missing file exits 66" {
	stub_pbcopy
	run_bin_with_env cb "CB_BACKEND=pbcopy" -- --file "${BIN_TEST_HOME}/no-such-file"
	assert_status 66
}

@test "cb exits 69 when no clipboard backend is available" {
	# Shadow all backends with failing stubs.
	make_stub "pbcopy" 127 ""
	make_stub "wl-copy" 127 ""
	make_stub "xclip" 127 ""
	make_stub "xsel" 127 ""
	make_stub "clip.exe" 127 ""
	run_bin_with_env cb "CB_BACKEND=auto" -- hello
	assert_status 69
}
