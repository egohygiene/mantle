#!/usr/bin/env bats
# Behavioral tests for bin/shell-banner.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

# ---------------------------------------------------------------------------
# Help and version
# ---------------------------------------------------------------------------

@test "shell-banner --help exits 0 and prints usage" {
	run_bin shell-banner --help
	assert_success
	assert_output_contains "Usage"
}

@test "shell-banner --version exits 0 and prints a version" {
	run_bin shell-banner --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Unknown option
# ---------------------------------------------------------------------------

@test "shell-banner unknown option exits 64" {
	run_bin shell-banner --no-such-flag
	assert_status 64
}

# ---------------------------------------------------------------------------
# Nonempty output
# ---------------------------------------------------------------------------

@test "shell-banner with no banner file produces nonempty output" {
	run_bin_with_env shell-banner \
		"MANTLE_BANNER_FILE=" \
		"MANTLE_ROOT=" \
		"XDG_CONFIG_HOME=${BIN_TEST_HOME}/.config" \
		-- --no-git
	# Accepts exit 0 (context only) or exit 66 (explicit file not found).
	[[ "${status}" -eq 0 || "${status}" -eq 66 ]]
	# When it succeeds, there must be some output.
	if [[ "${status}" -eq 0 ]]; then
		[[ -n "${output}" ]]
	fi
}

# ---------------------------------------------------------------------------
# --no-git flag
# ---------------------------------------------------------------------------

@test "shell-banner --no-git exits 0 without errors" {
	run_bin shell-banner --no-git
	assert_success
}

# ---------------------------------------------------------------------------
# --logo-only flag
# ---------------------------------------------------------------------------

@test "shell-banner --logo-only with a banner file renders the banner" {
	local banner_file="${BIN_TEST_HOME}/banner.txt"
	printf 'MANTLE\n' >"${banner_file}"
	run_bin_with_env shell-banner \
		"MANTLE_BANNER_FILE=${banner_file}" \
		-- --logo-only
	assert_success
	assert_output_contains "MANTLE"
}

# ---------------------------------------------------------------------------
# --file option
# ---------------------------------------------------------------------------

@test "shell-banner --file reads from given path" {
	local banner_file="${BIN_TEST_HOME}/my-banner.txt"
	printf 'HELLO BANNER\n' >"${banner_file}"
	run_bin shell-banner --file "${banner_file}" --logo-only
	assert_success
	assert_output_contains "HELLO BANNER"
}

@test "shell-banner --file with missing file exits 66" {
	run_bin shell-banner --file "${BIN_TEST_HOME}/does-not-exist.txt"
	assert_status 66
}

# ---------------------------------------------------------------------------
# Stderr is clean (diagnostics must not corrupt stdout)
# ---------------------------------------------------------------------------

@test "shell-banner stdout does not contain error prefix on success" {
	local banner_file="${BIN_TEST_HOME}/banner.txt"
	printf 'TEST\n' >"${banner_file}"
	run_bin_with_env shell-banner "MANTLE_BANNER_FILE=${banner_file}" -- --logo-only
	assert_success
	assert_output_not_contains "error:"
}

# ---------------------------------------------------------------------------
# No network access
# ---------------------------------------------------------------------------

@test "shell-banner does not invoke curl or wget" {
	make_stub "curl" 1 ""
	make_stub "wget" 1 ""
	run_bin shell-banner --no-git
	# Should succeed even if curl/wget are broken, because it never calls them.
	assert_success
}
