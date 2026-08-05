#!/usr/bin/env bats
# Behavioral tests for bin/git-clone-orgs.

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

@test "git-clone-orgs --help exits 0 and prints usage" {
	run_bin git-clone-orgs --help
	assert_success
	assert_output_contains "Usage"
}

@test "git-clone-orgs --version exits 0 and prints a version" {
	run_bin git-clone-orgs --version
	assert_success
	assert_valid_version
}

@test "git-clone-orgs unknown option exits non-zero" {
	run_bin git-clone-orgs --no-such-flag
	assert_failure
}

@test "git-clone-orgs exits non-zero without arguments" {
	run_bin git-clone-orgs
	assert_failure
}

@test "git-clone-orgs exits non-zero when gh is unavailable" {
	make_stub "gh" 127 ""
	run_bin git-clone-orgs myorg
	assert_failure
}
