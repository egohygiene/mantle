#!/usr/bin/env bats
# Behavioral tests for bin/git-remove-exec-no-shebang.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
	# Create a minimal git repo fixture.
	REPO_DIR="${BIN_TEST_HOME}/repo"
	mkdir -p "${REPO_DIR}"
	git -C "${REPO_DIR}" init -q 2>/dev/null
	git -C "${REPO_DIR}" config user.email "test@mantle"
	git -C "${REPO_DIR}" config user.name "Mantle Test"
}

teardown() {
	bin_test_teardown
}

@test "git-remove-exec-no-shebang --help exits 0 and prints usage" {
	run_bin git-remove-exec-no-shebang --help
	assert_success
	assert_output_contains "Usage"
}

@test "git-remove-exec-no-shebang --version exits 0 and prints a version" {
	run_bin git-remove-exec-no-shebang --version
	assert_success
	assert_valid_version
}

@test "git-remove-exec-no-shebang unknown option exits non-zero" {
	run_bin git-remove-exec-no-shebang --no-such-flag
	assert_failure
}

@test "git-remove-exec-no-shebang leaves executable with shebang alone" {
	local f="${REPO_DIR}/with_shebang.sh"
	printf '#!/bin/sh\necho hi\n' >"${f}"
	chmod 0755 "${f}"
	git -C "${REPO_DIR}" add "${f}" 2>/dev/null
	run bash -c "cd '${REPO_DIR}' && '${MANTLE_ROOT}/bin/git-remove-exec-no-shebang'"
	assert_success
	[[ -x "${f}" ]]
}

@test "git-remove-exec-no-shebang removes exec bit from file without shebang" {
	local f="${REPO_DIR}/no_shebang.txt"
	printf 'just text\n' >"${f}"
	chmod 0755 "${f}"
	git -C "${REPO_DIR}" add "${f}" 2>/dev/null
	run bash -c "cd '${REPO_DIR}' && '${MANTLE_ROOT}/bin/git-remove-exec-no-shebang'"
	assert_success
	[[ ! -x "${f}" ]]
}

@test "git-remove-exec-no-shebang on empty tree exits 0" {
	run bash -c "cd '${REPO_DIR}' && '${MANTLE_ROOT}/bin/git-remove-exec-no-shebang'"
	assert_success
}
