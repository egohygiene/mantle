#!/usr/bin/env bats
# Behavioral tests for bin/generate-tree.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
	WORK_DIR="${BIN_TEST_HOME}/work"
	mkdir -p "${WORK_DIR}"
}

teardown() {
	bin_test_teardown
}

@test "generate-tree --help exits 0 and prints usage" {
	run_bin generate-tree --help
	assert_success
	assert_output_contains "Usage"
}

@test "generate-tree --version exits 0 and prints a version" {
	run_bin generate-tree --version
	assert_success
	assert_valid_version
}

@test "generate-tree unknown option exits non-zero" {
	run_bin generate-tree --no-such-flag
	assert_failure
}

@test "generate-tree --stdout inside a git repo exits 0" {
	if ! command -v git >/dev/null 2>&1; then skip "git not available"; fi
	# create a minimal git repo
	local repo_dir="${BIN_TEST_HOME}/repo"
	mkdir -p "${repo_dir}"
	git -C "${repo_dir}" init -q 2>/dev/null
	git -C "${repo_dir}" config user.email "t@t"
	git -C "${repo_dir}" config user.name "T"
	run bash -c "cd '${repo_dir}' && '${MANTLE_ROOT}/bin/generate-tree' --stdout"
	assert_success
}

@test "generate-tree exits non-zero outside a git worktree" {
	run bash -c "cd '${BIN_TEST_HOME}' && '${MANTLE_ROOT}/bin/generate-tree' --stdout"
	assert_failure
}
