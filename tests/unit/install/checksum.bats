#!/usr/bin/env bats
# Unit tests for lib/install/checksum.sh

setup() {
	load '../../test_helper/common'
	load '../../test_helper/assertions'
	load '../../test_helper/fixtures'
	setup_isolated_home
	setup_stub_dir

	# Load the runtime (which loads checksum.sh)
	RUNTIME_LOADED=0
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

_bash_checksum() {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/install/runtime.sh'
		$*
	"
}

# ---------------------------------------------------------------------------
# mantle_install_checksum_calculate
# ---------------------------------------------------------------------------

@test "checksum_calculate returns a SHA-256 digest for a known file" {
	local test_file="${TEST_HOME}/checksum_input.txt"
	printf "hello mantle\n" >"${test_file}"
	_bash_checksum "mantle_install_checksum_calculate sha256 '${test_file}'"
	assert_success
	# digest must be 64 hex chars
	[[ "${lines[0]}" =~ ^[0-9a-f]{64}$ ]]
}

@test "checksum_calculate returns a SHA-512 digest" {
	local test_file="${TEST_HOME}/checksum_input512.txt"
	printf "hello mantle\n" >"${test_file}"
	_bash_checksum "mantle_install_checksum_calculate sha512 '${test_file}'"
	assert_success
	[[ "${lines[0]}" =~ ^[0-9a-f]{128}$ ]]
}

@test "checksum_calculate returns 64 for an unsupported algorithm" {
	local test_file="${TEST_HOME}/file.txt"
	printf "x\n" >"${test_file}"
	_bash_checksum "mantle_install_checksum_calculate md5 '${test_file}'; printf '%d\n' \$?"
	assert_output_contains "64"
}

@test "checksum_calculate returns 64 for a missing file" {
	_bash_checksum "mantle_install_checksum_calculate sha256 '/no/such/file'; printf '%d\n' \$?"
	assert_output_contains "64"
}

# ---------------------------------------------------------------------------
# mantle_install_checksum_verify
# ---------------------------------------------------------------------------

@test "checksum_verify succeeds when digest matches" {
	local test_file="${TEST_HOME}/verify_input.txt"
	printf "hello mantle\n" >"${test_file}"
	_bash_checksum "
		digest=\"\$(mantle_install_checksum_calculate sha256 '${test_file}')\"
		mantle_install_checksum_verify sha256 '${test_file}' \"\${digest}\" \
			&& printf 'ok\n' || printf 'mismatch\n'
	"
	assert_success
	assert_output_contains "ok"
}

@test "checksum_verify fails when digest does not match" {
	local test_file="${TEST_HOME}/bad_input.txt"
	printf "wrong content\n" >"${test_file}"
	_bash_checksum "
		mantle_install_checksum_verify sha256 '${test_file}' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
			&& printf 'ok\n' || printf 'mismatch\n'
	"
	assert_output_contains "mismatch"
}

@test "checksum.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/install/checksum.sh"
	assert_status 64
}
