#!/usr/bin/env bats
# Behavioral tests for bin/apt-freeze, bin/apt-install, and bin/apt-base.

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
# apt-freeze
# ===========================================================================

@test "apt-freeze --help exits 0 and prints usage" {
	run_bin apt-freeze --help
	assert_success
	assert_output_contains "Usage"
}

@test "apt-freeze --version exits 0 and prints a version" {
	run_bin apt-freeze --version
	assert_success
	assert_valid_version
}

@test "apt-freeze unknown option exits non-zero" {
	run_bin apt-freeze --no-such-flag
	assert_failure
}

@test "apt-freeze dry-run never writes an export bundle" {
	local output_directory="${BIN_TEST_HOME}/apt-export"
	run_bin apt-freeze --dry-run --output-dir "${output_directory}"
	# Non-Ubuntu hosts can reject the platform or lack APT inventory tools.
	[[ "${status}" -eq 0 || "${status}" -eq 4 || "${status}" -eq 127 ]]
	[[ ! -e "${output_directory}" ]]
}

# ===========================================================================
# apt-install
# ===========================================================================

@test "apt-install --help exits 0 and prints usage" {
	run_bin apt-install --help
	assert_success
	assert_output_contains "Usage"
}

@test "apt-install --version exits 0 and prints a version" {
	run_bin apt-install --version
	assert_success
	assert_valid_version
}

@test "apt-install unknown option exits non-zero" {
	run_bin apt-install --no-such-flag
	assert_failure
}

@test "apt-install requires root and fails without sudo or root" {
	local package_file="${BIN_TEST_HOME}/packages.txt"
	printf "curl\n" >"${package_file}"
	make_stub "id" 0 "1000"
	make_stub "sudo" 1 ""
	run_bin apt-install --lock --packages-file "${package_file}" --yes
	assert_failure
	[[ "${status}" -eq 77 ]]
	assert_output_contains "APT requires root"
}

@test "apt-install dry-run handles empty package and privilege arrays before planning" {
	local package_file="${BIN_TEST_HOME}/packages.txt"
	printf "curl\ncurl\n" >"${package_file}"
	make_stub "id" 0 "1000"
	make_recording_stub apt-get 99 ""
	run_bin apt-install --lock --packages-file "${package_file}" --dry-run
	assert_success
	assert_output_contains "packages: 1"
	assert_output_contains "--no-remove curl"
	[[ "$(recording_stub_calls apt-get)" -eq 0 ]]
}

# ===========================================================================
# apt-base
# ===========================================================================

@test "apt-base --help exits 0 and prints usage" {
	run_bin apt-base --help
	assert_success
	assert_output_contains "Usage"
}

@test "apt-base --version exits 0 and prints a version" {
	run_bin apt-base --version
	assert_success
	assert_valid_version
}

@test "apt-base requires root and fails without sudo or root" {
	make_stub "id" 0 "1000"
	make_stub "sudo" 1 ""
	run_bin apt-base --yes
	assert_failure
	[[ "${status}" -eq 77 ]]
	assert_output_contains "APT requires root"
}

@test "apt-base forwards an empty option list without bypassing privilege checks" {
	make_stub "id" 0 "1000"
	run_bin apt-base --lock
	assert_status 77
	assert_output_contains "APT requires root"
}
