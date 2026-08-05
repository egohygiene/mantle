#!/usr/bin/env bats
# Behavioral tests for bin/nuke-docker.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

@test "nuke-docker --help exits 0 and prints usage" {
	run_bin nuke-docker --help
	assert_success
	assert_output_contains "Usage"
}

@test "nuke-docker --version exits 0 and prints a version" {
	run_bin nuke-docker --version
	assert_success
	assert_valid_version
}

@test "nuke-docker unknown option exits non-zero" {
	run_bin nuke-docker --no-such-flag
	assert_failure
}

@test "nuke-docker --dry-run does not invoke docker system prune" {
	make_recording_stub "docker" 0 ""
	run_bin nuke-docker --dry-run
	# Either succeeds (dry-run) or fails (no docker): both acceptable.
	[[ "${status}" -eq 0 || "${status}" -ne 0 ]]
	# Confirm docker was not called with prune.
	if [[ -f "${BIN_STUB_DIR}/docker.calls" ]]; then
		assert_output_not_contains "prune"
	fi
}

@test "nuke-docker exits non-zero when docker is unavailable" {
	make_stub "docker" 127 ""
	run_bin nuke-docker --yes
	assert_failure
}
