#!/usr/bin/env bats
# Behavioral tests for bin/gitignore-cleaner.

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

@test "gitignore-cleaner --help exits 0 and prints usage" {
	run_bin gitignore-cleaner --help
	assert_success
	assert_output_contains "usage:"
}

@test "gitignore-cleaner --version exits 0 and prints a version" {
	run_bin gitignore-cleaner --version
	assert_success
	assert_valid_version
}

@test "gitignore-cleaner unknown option exits 2" {
	run_bin gitignore-cleaner --no-such-flag
	assert_status 2
}

@test "gitignore-cleaner removes semantically redundant rules from stdin" {
	cat <<'EOF' >"${WORK_DIR}/sample.gitignore"
# top
node_modules/
/node_modules/
*.log
npm-debug.log
EOF

	run bash -c "cat '${WORK_DIR}/sample.gitignore' | '${MANTLE_ROOT}/bin/gitignore-cleaner'"
	assert_success
	assert_output_contains "# top"
	assert_output_contains "node_modules/"
	assert_output_contains "*.log"
	assert_output_not_contains "/node_modules/"
	assert_output_not_contains "npm-debug.log"
}
