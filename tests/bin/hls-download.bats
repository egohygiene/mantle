#!/usr/bin/env bats
# Standalone HLS alias behavior; media processing has integration coverage.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

# @description Expose shell prerequisites while deliberately omitting media tools and Python.
_hls_alias_minimal_path() {
	local tool
	for tool in bash dirname basename readlink; do
		ln -s "$(command -v "${tool}")" "${BIN_STUB_DIR}/${tool}"
	done
}

@test "hls-download help and version do not require Python FFmpeg or ffprobe" {
	_hls_alias_minimal_path
	run env -i HOME="${BIN_TEST_HOME}" PATH="${BIN_STUB_DIR}" \
		"${MANTLE_ROOT}/bin/hls-download" --help
	assert_success
	assert_output_contains "Usage: mantle hls-download"
	assert_output_contains "--retry-count"
	assert_output_contains "--inherit-query"
	run env -i HOME="${BIN_TEST_HOME}" PATH="${BIN_STUB_DIR}" \
		"${MANTLE_ROOT}/bin/hls-download" --version
	assert_success
	assert_output_contains "hls-download 1.0.0"
	assert_valid_version
}

@test "hls-download rejects unknown options without optional dependencies or echoing values" {
	_hls_alias_minimal_path
	run env -i HOME="${BIN_TEST_HOME}" PATH="${BIN_STUB_DIR}" \
		"${MANTLE_ROOT}/bin/hls-download" --unknown-secret-fixture
	assert_status 64
	assert_output_not_contains "unknown-secret-fixture"
}

@test "hls-download requires a source before checking optional dependencies" {
	_hls_alias_minimal_path
	run env -i HOME="${BIN_TEST_HOME}" PATH="${BIN_STUB_DIR}" \
		"${MANTLE_ROOT}/bin/hls-download"
	assert_status 64
	assert_output_contains "Usage"
}

@test "hls-download follows an external symbolic link to the same canonical command" {
	ln -s "${MANTLE_ROOT}/bin/hls-download" "${BIN_TEST_HOME}/download-alias"
	run env -i HOME="${BIN_TEST_HOME}" PATH="${PATH}" \
		"${BIN_TEST_HOME}/download-alias" --version
	assert_success
	assert_output_contains "hls-download 1.0.0"
}

@test "hls-download alias and mantle command report identical help" {
	run_bin hls-download --help
	assert_success
	local alias_help="${output}"
	run_bin mantle hls-download --help
	assert_success
	[[ "${output}" == "${alias_help}" ]]
}
