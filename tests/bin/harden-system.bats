#!/usr/bin/env bats
# Behavioral tests for bin/harden-system.

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

@test "harden-system --help exits 0 and prints usage" {
	run_bin harden-system --help
	assert_success
	assert_output_contains "Usage"
}

@test "harden-system --version exits 0 and prints a version" {
	run_bin harden-system --version
	assert_success
	assert_valid_version
}

@test "harden-system unknown option exits 2 with a usage diagnostic" {
	run_bin harden-system --no-such-flag
	assert_status 2
	assert_output_contains "unknown command: --no-such-flag"
}

@test "harden-system help accepts global options without command arguments" {
	run_bin harden-system help --dry-run
	assert_success
	assert_output_contains "Usage"
}

@test "harden-system rejects an invalid global format before running a command" {
	run_bin harden-system audit --format invalid
	assert_status 2
	assert_output_contains "--format must be text or json"
}

@test "harden-system offline firewall dry-run handles omitted SSH sources" {
	[[ "$(uname -s)" == Linux ]] || skip "Linux firewall facilities require Linux"
	make_recording_stub firewall-cmd 1 ""
	make_recording_stub firewall-offline-cmd 0 ""
	make_recording_stub systemctl 99 ""
	run_bin harden-system firewall --backend firewalld --allow-ssh --dry-run
	assert_success
	assert_output_contains "firewall-offline-cmd --add-service=ssh"
	[[ "$(recording_stub_calls firewall-offline-cmd)" -eq 0 ]]
	[[ "$(recording_stub_calls systemctl)" -eq 0 ]]
}
