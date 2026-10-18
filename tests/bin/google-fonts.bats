#!/usr/bin/env bats
# Behavioral tests for bin/google-fonts.

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

@test "google-fonts --help exits 0 and prints usage" {
	run_bin google-fonts --help
	assert_success
	assert_output_contains "Usage"
}

@test "google-fonts --version exits 0 and prints a version" {
	run_bin google-fonts --version
	assert_success
	assert_valid_version
}

@test "google-fonts unknown option exits non-zero" {
	run_bin google-fonts --no-such-flag
	assert_failure
}

@test "google-fonts preserves a download failure status through cleanup" {
	make_stub "wget" 8 ""
	make_stub "curl" 22 ""
	run_bin google-fonts --all --yes --download-method archive
	assert_status 22
}

@test "google-fonts requires confirmation for its default all-family installation" {
	run_bin google-fonts
	assert_status 1
	assert_output_contains "Confirmation is required in non-interactive mode"
}

@test "google-fonts defaults to an all-family dry-run with default licenses" {
	make_recording_stub curl 99 ""
	make_recording_stub wget 99 ""
	run_bin google-fonts --dry-run
	assert_success
	assert_output_contains "Selection:     all families"
	assert_output_contains "Licenses:      ofl apache ufl"
	[[ "$(recording_stub_calls curl)" -eq 0 ]]
	[[ "$(recording_stub_calls wget)" -eq 0 ]]
}
