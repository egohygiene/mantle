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

@test "git-remove-exec-no-shebang uses a portable chmod mode and protects dash-prefixed paths" {
	local real_chmod
	real_chmod="$(command -v chmod)"
	printf 'plain text\n' >"${REPO_DIR}/-plain name.txt"
	printf '#!/bin/sh\nexit 0\n' >"${REPO_DIR}/-script.sh"
	chmod 0755 "${REPO_DIR}/-plain name.txt" "${REPO_DIR}/-script.sh"
	git -C "${REPO_DIR}" add -- '-plain name.txt' '-script.sh'
	cat >"${BIN_STUB_DIR}/chmod" <<'SH'
#!/bin/sh
# Emulate BSD chmod's lack of GNU-style option termination after the mode.
[ "$#" -eq 2 ] && [ "$1" = a-x ] || exit 91
case "$2" in ./*) ;; *) exit 92 ;; esac
exec "$MANTLE_TEST_REAL_CHMOD" "$@"
SH
	chmod 0755 "${BIN_STUB_DIR}/chmod"
	# shellcheck disable=SC2016 # Resolve fixture variables in the child process.
	run env MANTLE_TEST_REAL_CHMOD="${real_chmod}" REPO_DIR="${REPO_DIR}" \
		bash -c 'cd "$REPO_DIR" && "$MANTLE_ROOT/bin/git-remove-exec-no-shebang"'
	assert_success
	[[ ! -x "${REPO_DIR}/-plain name.txt" ]]
	[[ -x "${REPO_DIR}/-script.sh" ]]
}
