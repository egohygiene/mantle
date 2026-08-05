#!/usr/bin/env bats
# Behavioral tests for bin/bcrypt-password.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

_has_bcrypt() {
	python3 -c "import bcrypt" 2>/dev/null
}

@test "bcrypt-password --help exits 0 and prints usage" {
	run_bin bcrypt-password --help
	assert_success
	# Python argparse uses "usage:" (lowercase)
	assert_output_contains "usage"
}

@test "bcrypt-password --version exits 0 and prints a version" {
	run_bin bcrypt-password --version
	assert_success
	assert_valid_version
}

@test "bcrypt-password unknown option exits non-zero" {
	run_bin bcrypt-password --no-such-flag
	assert_failure
}

@test "bcrypt-password hash mode with --stdin exits 0 with bcrypt available" {
	if ! _has_bcrypt; then skip "python3 bcrypt module not available"; fi
	run bash -c "printf 'mypassword\n' | '${MANTLE_ROOT}/bin/bcrypt-password' hash --stdin"
	assert_success
	# Output should look like a bcrypt hash.
	printf "%s\n" "${output}" | grep -q '^\$2'
}

@test "bcrypt-password hash does not accept password on argv" {
	if ! _has_bcrypt; then skip "python3 bcrypt module not available"; fi
	run_bin bcrypt-password hash mypassword
	assert_failure
}

@test "bcrypt-password verify mode exits 0 for correct password" {
	if ! _has_bcrypt; then skip "python3 bcrypt module not available"; fi
	local hash
	hash="$(printf 'mypassword\n' | "${MANTLE_ROOT}/bin/bcrypt-password" hash --stdin)"
	run bash -c "printf 'mypassword\n' | '${MANTLE_ROOT}/bin/bcrypt-password' verify --stdin '${hash}'"
	assert_success
}

@test "bcrypt-password verify mode exits non-zero for wrong password" {
	if ! _has_bcrypt; then skip "python3 bcrypt module not available"; fi
	local hash
	hash="$(printf 'mypassword\n' | "${MANTLE_ROOT}/bin/bcrypt-password" hash --stdin)"
	run bash -c "printf 'wrongpassword\n' | '${MANTLE_ROOT}/bin/bcrypt-password' verify --stdin '${hash}'"
	assert_failure
}

@test "bcrypt-password exits non-zero when python3 is unavailable" {
	local empty_dir="${BIN_TEST_HOME}/empty-bin"
	mkdir -p "${empty_dir}"
	run env -i \
		HOME="${BIN_TEST_HOME}" \
		PATH="${empty_dir}:/usr/sbin:/sbin" \
		TERM=dumb CI=true \
		"${MANTLE_ROOT}/bin/bcrypt-password" hash
	assert_failure
}
