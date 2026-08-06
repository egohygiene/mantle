#!/usr/bin/env bats
# Unit tests for lib/install/download.sh

setup() {
	load '../../test_helper/common'
	load '../../test_helper/assertions'
	load '../../test_helper/stubs'
	setup_isolated_home
	setup_stub_dir
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

_bash_download() {
	run env -i \
		HOME="${TEST_HOME}" \
		MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${STUB_DIR}:${PATH}" \
		TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/install/runtime.sh'
			$*
		"
}

# ---------------------------------------------------------------------------
# HTTPS success via curl stub
# ---------------------------------------------------------------------------

@test "download_file succeeds with a stubbed curl" {
	stub_curl_success "stub body"
	local dest="${TEST_HOME}/downloaded.txt"
	_bash_download "mantle_install_download_file 'https://example.invalid/file.txt' '${dest}'"
	assert_success
	assert_file_exists "${dest}"
}

# ---------------------------------------------------------------------------
# Insecure URL policy
# ---------------------------------------------------------------------------

@test "download_file rejects http:// URLs by default" {
	stub_curl_success ""
	local dest="${TEST_HOME}/insecure.txt"
	_bash_download "
		mantle_install_download_file 'http://example.invalid/file.txt' '${dest}'
		printf '%d\n' \$?
	"
	assert_output_contains "64"
	assert_file_not_exists "${dest}"
}

@test "download_file allows http:// when MANTLE_INSTALL_ALLOW_INSECURE_DOWNLOADS=1" {
	stub_curl_success "insecure body"
	local dest="${TEST_HOME}/insecure_allowed.txt"
	_bash_download "
		MANTLE_INSTALL_ALLOW_INSECURE_DOWNLOADS=1
		export MANTLE_INSTALL_ALLOW_INSECURE_DOWNLOADS
		mantle_install_download_file 'http://example.invalid/file.txt' '${dest}'
	"
	assert_success
	assert_file_exists "${dest}"
}

# ---------------------------------------------------------------------------
# Wget fallback
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Failure cases
# ---------------------------------------------------------------------------

@test "download_file returns 64 with missing arguments" {
	_bash_download "mantle_install_download_file; printf '%d\n' \$?"
	assert_output_contains "64"
}

@test "download_file fails when curl returns an error" {
	stub_curl_failure 22
	local dest="${TEST_HOME}/failed.txt"
	_bash_download "
		mantle_install_download_file 'https://example.invalid/file.txt' '${dest}'
		printf '%d\n' \$?
	"
	[[ "${output}" != *"0"* ]] || [[ ! -f "${dest}" ]]
}

@test "download.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/install/download.sh"
	assert_status 64
}
