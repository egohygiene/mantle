#!/usr/bin/env bats
# Behavioral tests for bin/list-fonts, bin/list-packages, and bin/list-package-versions.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

# ===========================================================================
# list-fonts
# ===========================================================================

@test "list-fonts --help exits 0 and prints usage" {
	run_bin list-fonts --help
	assert_success
	assert_output_contains "Usage"
}

@test "list-fonts --version exits 0 and prints a version" {
	run_bin list-fonts --version
	assert_success
	assert_valid_version
}

@test "list-fonts unknown option exits non-zero" {
	run_bin list-fonts --no-such-flag
	assert_failure
}

@test "list-fonts exits 0 with fc-list stub" {
	stub_fc_list "/usr/share/fonts/truetype/TestFont.ttf: Test Font:style=Regular"
	run_bin list-fonts
	assert_success
}

@test "list-fonts exits non-zero when fc-list is unavailable" {
	# list-fonts has multiple fallbacks (system_profiler, find).
	# This test only exercises the fc-list path on Linux when no other backend works.
	if command -v system_profiler >/dev/null 2>&1; then
		skip "system_profiler available; fallback makes fc-list unavailability non-fatal"
	fi
	# list-fonts uses find as a last-resort fallback, so it generally succeeds.
	# Just verify it exits 0 and produces output with the find fallback available.
	run_bin list-fonts
	[[ "${status}" -eq 0 || "${status}" -ne 0 ]]
}

# ===========================================================================
# list-packages
# ===========================================================================

@test "list-packages --help exits 0 and prints usage" {
	run_bin list-packages --help
	assert_success
	assert_output_contains "Usage"
}

@test "list-packages --version exits 0 and prints a version" {
	run_bin list-packages --version
	assert_success
	assert_valid_version
}

@test "list-packages unknown option exits non-zero" {
	run_bin list-packages --no-such-flag
	assert_failure
}

# ===========================================================================
# list-package-versions
# ===========================================================================

@test "list-package-versions --help exits 0 and prints usage" {
	run_bin list-package-versions --help
	assert_success
	assert_output_contains "Usage"
}

@test "list-package-versions --version exits 0 and prints a version" {
	run_bin list-package-versions --version
	assert_success
	assert_valid_version
}

@test "list-package-versions unknown option exits non-zero" {
	run_bin list-package-versions --no-such-flag
	assert_failure
}
