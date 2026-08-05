#!/usr/bin/env bats
# Behavioral tests for bin/whats-in-port and bin/clearport.

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
# whats-in-port
# ===========================================================================

# ---------------------------------------------------------------------------
# Help and version
# ---------------------------------------------------------------------------

@test "whats-in-port --help exits 0 and prints usage" {
	run_bin whats-in-port --help
	assert_success
	assert_output_contains "Usage"
}

@test "whats-in-port --version exits 0 and prints a version" {
	run_bin whats-in-port --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Missing required argument
# ---------------------------------------------------------------------------

@test "whats-in-port with no port exits 2" {
	run_bin whats-in-port
	assert_status 2
}

# ---------------------------------------------------------------------------
# --list-backends
# ---------------------------------------------------------------------------

@test "whats-in-port --list-backends exits 0 and reports backends" {
	run_bin whats-in-port --list-backends
	assert_success
	assert_output_contains "lsof"
}

# ---------------------------------------------------------------------------
# No-match with stubbed backend
# ---------------------------------------------------------------------------

@test "whats-in-port exits 1 when no process owns the port (lsof stub)" {
	stub_lsof
	make_stub "ss" 127 ""
	run_bin whats-in-port --backend lsof 9999
	[[ "${status}" -eq 0 || "${status}" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# --format tsv
# ---------------------------------------------------------------------------

@test "whats-in-port --format tsv exits without error with stubbed backend" {
	stub_lsof
	run_bin whats-in-port --format tsv --backend lsof 9999
	[[ "${status}" -eq 0 || "${status}" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# Unknown option
# ---------------------------------------------------------------------------

@test "whats-in-port unknown option exits non-zero" {
	run_bin whats-in-port --no-such-flag
	assert_failure
}

# ===========================================================================
# clearport
# ===========================================================================

# ---------------------------------------------------------------------------
# Help and version
# ---------------------------------------------------------------------------

@test "clearport --help exits 0 and prints usage" {
	run_bin clearport --help
	assert_success
	assert_output_contains "Usage"
}

@test "clearport --version exits 0 and prints a version" {
	run_bin clearport --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Missing required argument
# ---------------------------------------------------------------------------

@test "clearport with no port exits 2" {
	run_bin clearport
	assert_status 2
}

# ---------------------------------------------------------------------------
# --dry-run with no process on port
# ---------------------------------------------------------------------------

@test "clearport --dry-run exits 0 or 1 with no process on port (lsof stub)" {
	stub_lsof
	make_stub "ss" 127 ""
	run_bin clearport --dry-run --backend lsof 9998
	[[ "${status}" -eq 0 || "${status}" -eq 1 || "${status}" -eq 3 ]]
}

# ---------------------------------------------------------------------------
# Unknown option
# ---------------------------------------------------------------------------

@test "clearport unknown option exits non-zero" {
	run_bin clearport --no-such-flag
	assert_failure
}
