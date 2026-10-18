#!/usr/bin/env bats
# Behavioral tests for bin/textfind — text search with backend fallback.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
	WORK_DIR="${BIN_TEST_HOME}/work"
	mkdir -p "${WORK_DIR}"
}

teardown() {
	bin_test_teardown
}

# ---------------------------------------------------------------------------
# Help and version
# ---------------------------------------------------------------------------

@test "textfind --help exits 0 and prints usage" {
	run_bin textfind --help
	assert_success
	assert_output_contains "Usage"
}

@test "textfind --version exits 0 and prints a version" {
	run_bin textfind --version
	assert_success
	assert_valid_version
}

# ---------------------------------------------------------------------------
# Literal match
# ---------------------------------------------------------------------------

@test "textfind finds literal text in a file" {
	printf "hello world\n" >"${WORK_DIR}/file.txt"
	run_bin textfind "hello" "${WORK_DIR}"
	assert_success
}

@test "textfind exits 1 when no match is found" {
	printf "hello world\n" >"${WORK_DIR}/file.txt"
	run_bin textfind "no_such_string_xyz" "${WORK_DIR}"
	assert_status 1
}

# ---------------------------------------------------------------------------
# --ignore-case
# ---------------------------------------------------------------------------

@test "textfind --ignore-case finds case-insensitive match" {
	printf "Hello World\n" >"${WORK_DIR}/file.txt"
	run_bin textfind --ignore-case "hello" "${WORK_DIR}"
	assert_success
}

# ---------------------------------------------------------------------------
# --regex
# ---------------------------------------------------------------------------

@test "textfind --regex matches a regex pattern" {
	printf "TODO fix this\nFIXME that\n" >"${WORK_DIR}/file.txt"
	run_bin textfind --regex "TODO|FIXME" "${WORK_DIR}"
	assert_success
}

# ---------------------------------------------------------------------------
# --files-only
# ---------------------------------------------------------------------------

@test "textfind --files-only prints only file paths, not match content" {
	printf "needle\n" >"${WORK_DIR}/haystack.txt"
	run_bin textfind --files-only "needle" "${WORK_DIR}"
	assert_success
	assert_output_contains "haystack.txt"
	assert_output_not_contains "needle"
}

@test "textfind grep fallback probes real options without requiring GNU help" {
	local real_grep
	real_grep="$(command -v grep)"
	{
		printf '#!/bin/sh\n'
		printf 'if [ "$1" = "--help" ]; then exit 2; fi\n'
		printf 'exec %q "$@"\n' "${real_grep}"
	} >"${BIN_STUB_DIR}/grep"
	chmod 0755 "${BIN_STUB_DIR}/grep"
	mkdir -p "${WORK_DIR}/excluded" "${WORK_DIR}/.git"
	printf "needle\n" >"${WORK_DIR}/keep.txt"
	printf "needle\n" >"${WORK_DIR}/ignore.txt"
	printf "needle\n" >"${WORK_DIR}/other.log"
	printf "needle\n" >"${WORK_DIR}/excluded/nested.txt"
	printf "needle\n" >"${WORK_DIR}/.git/metadata.txt"
	run /bin/bash "${MANTLE_ROOT}/bin/textfind" --backend grep --files-only \
		--include '*.txt' --exclude ignore.txt --exclude-dir excluded needle "${WORK_DIR}"
	assert_success
	[[ "${output}" == "${WORK_DIR}/keep.txt" ]]
}

@test "textfind grep fallback rejects a backend that cannot parse glob options" {
	make_stub grep 2 ""
	printf "needle\n" >"${WORK_DIR}/keep.txt"
	run /bin/bash "${MANTLE_ROOT}/bin/textfind" --backend grep needle "${WORK_DIR}"
	assert_status 4
	assert_output_contains "grep lacks --include/--exclude support"
	assert_output_not_contains "keep.txt"
}

@test "textfind grep fallback supports an empty optional glob selection under stock Bash" {
	printf "needle\n" >"${WORK_DIR}/keep.txt"
	run /bin/bash "${MANTLE_ROOT}/bin/textfind" --backend grep needle "${WORK_DIR}"
	assert_success
	assert_output_contains "keep.txt:1:needle"
}

# ---------------------------------------------------------------------------
# Missing pattern
# ---------------------------------------------------------------------------

@test "textfind with no pattern exits 2" {
	run_bin textfind
	assert_status 2
}

# ---------------------------------------------------------------------------
# No backend
# ---------------------------------------------------------------------------

@test "textfind exits 3 when no backend is available" {
	# This test is only meaningful on a system where neither rg nor grep is available.
	if command -v rg >/dev/null 2>&1 || command -v grep >/dev/null 2>&1; then
		skip "a search backend is available system-wide; no-backend path cannot be exercised"
	fi
	printf "data\n" >"${WORK_DIR}/file.txt"
	run_bin textfind "data" "${WORK_DIR}"
	assert_status 3
}

# ---------------------------------------------------------------------------
# Unknown option
# ---------------------------------------------------------------------------

@test "textfind unknown option exits 2" {
	run_bin textfind --no-such-flag
	assert_status 2
}
