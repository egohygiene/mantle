#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Behavioral tests for the Mantle validation runner itself.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	load '../test_helper/stubs'
	setup_isolated_home
	setup_stub_dir
	RUNNER="${MANTLE_ROOT}/tests/run.sh"
	FIXTURE_ROOT="${TEST_HOME}/validation-root"
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

create_validation_fixture() {
	mkdir -p \
		"${FIXTURE_ROOT}/bin" \
		"${FIXTURE_ROOT}/config" \
		"${FIXTURE_ROOT}/init" \
		"${FIXTURE_ROOT}/lib" \
		"${FIXTURE_ROOT}/libexec/mantle/commands" \
		"${FIXTURE_ROOT}/modules" \
		"${FIXTURE_ROOT}/platforms" \
		"${FIXTURE_ROOT}/scripts" \
		"${FIXTURE_ROOT}/runtime/shared" \
		"${FIXTURE_ROOT}/runtime/shells/bash" \
		"${FIXTURE_ROOT}/runtime/shells/fish" \
		"${FIXTURE_ROOT}/runtime/shells/posix" \
		"${FIXTURE_ROOT}/runtime/shells/zsh" \
		"${FIXTURE_ROOT}/tests/bin" \
		"${FIXTURE_ROOT}/tests/contract" \
		"${FIXTURE_ROOT}/tests/integration" \
		"${FIXTURE_ROOT}/tests/unit"

	printf '%s\n' '# shell entrypoint fixture' >"${FIXTURE_ROOT}/.shellrc"
	printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${FIXTURE_ROOT}/bin/mantle"
	printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${FIXTURE_ROOT}/install.sh"
	printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${FIXTURE_ROOT}/tests/run.sh"
	printf '%s\n' '#!/bin/sh' 'exit 0' >"${FIXTURE_ROOT}/runtime/shared/runtime.sh"
	printf '%s\n' '#!/bin/sh' 'exit 0' >"${FIXTURE_ROOT}/runtime/shells/posix/runtime.sh"
	printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${FIXTURE_ROOT}/runtime/shells/bash/runtime.sh"
	printf '%s\n' '#!/usr/bin/env zsh' 'exit 0' >"${FIXTURE_ROOT}/runtime/shells/zsh/runtime.sh"
	printf '%s\n' 'exit 0' >"${FIXTURE_ROOT}/runtime/shells/fish/runtime.fish"
	printf '%s\n' '#!/usr/bin/env bats' '@test "fixture passes" { true; }' \
		>"${FIXTURE_ROOT}/tests/integration/fixture.bats"
	chmod 0755 "${FIXTURE_ROOT}/bin/mantle" "${FIXTURE_ROOT}/install.sh" "${FIXTURE_ROOT}/tests/run.sh"
}

run_fixture_static() {
	local validation_mode="${1:?}"
	local unavailable_tools="${2-zsh,fish,shellcheck,shdoc,shfmt}"

	run env \
		MANTLE_TEST_ROOT="${FIXTURE_ROOT}" \
		MANTLE_RUNNER_TEST_UNAVAILABLE_TOOLS="${unavailable_tools}" \
		"${RUNNER}" "${validation_mode}" static
}

@test "runner returns nonzero when a Bats test fails" {
	local failing_test="${TEST_HOME}/controlled-failure.bats"
	printf '%s\n' '#!/usr/bin/env bats' '@test "controlled failure" { false; }' >"${failing_test}"

	run "${RUNNER}" "${failing_test}"
	assert_failure
	assert_output_contains "not ok 1 controlled failure"
	assert_output_contains "status: failed"
}

@test "runner returns nonzero when a required directory is missing" {
	create_validation_fixture
	rmdir "${FIXTURE_ROOT}/config"

	run_fixture_static --local
	assert_failure
	assert_output_contains "Missing required directory: config/"
	assert_output_contains "status: failed"
}

@test "runner returns nonzero when source discovery fails" {
	create_validation_fixture
	create_stub find 23

	run_fixture_static --local
	assert_failure
	assert_output_contains "Unable to discover Bash sources"
	assert_output_contains "status: failed"
}

@test "runner returns nonzero for a Bash syntax error" {
	create_validation_fixture
	printf '%s\n' 'if then' >"${FIXTURE_ROOT}/init/broken.sh"

	run_fixture_static --local
	assert_failure
	assert_output_contains "Bash syntax error"
	assert_output_contains "failed: 1"
}

@test "runner returns nonzero for a POSIX syntax error" {
	create_validation_fixture
	printf '%s\n' 'if then' >"${FIXTURE_ROOT}/runtime/shared/runtime.sh"

	run_fixture_static --local
	assert_failure
	assert_output_contains "POSIX shell syntax error"
	assert_output_contains "status: failed"
}

@test "runner returns nonzero for a Zsh syntax error" {
	create_validation_fixture
	printf '%s\n' 'if then' >"${FIXTURE_ROOT}/runtime/shells/zsh/runtime.sh"

	run_fixture_static --local "fish,shellcheck,shdoc,shfmt"
	assert_failure
	assert_output_contains "Zsh syntax error"
	assert_output_contains "status: failed"
}

@test "runner returns nonzero for a Fish syntax error" {
	create_validation_fixture
	create_stub fish 1 "controlled Fish syntax failure"

	run_fixture_static --local "zsh,shellcheck,shdoc,shfmt"
	assert_failure
	assert_output_contains "Fish syntax error"
	assert_output_contains "status: failed"
}

@test "local validation records unavailable optional tools as skips" {
	create_validation_fixture

	run_fixture_static --local
	assert_success
	assert_output_contains "mode: local"
	assert_output_contains "failed: 0"
	assert_output_contains "skipped: 5"
	assert_output_contains "status: passed"
}

@test "strict validation rejects unavailable required tools" {
	create_validation_fixture

	run_fixture_static --strict
	assert_failure
	assert_output_contains "zsh is required in strict mode"
	assert_output_contains "fish is required in strict mode"
	assert_output_contains "shellcheck is required in strict mode"
	assert_output_contains "shdoc is required in strict mode"
	assert_output_contains "shfmt is required in strict mode"
	assert_output_contains "failed: 5"
	assert_output_contains "status: failed"
}

@test "strict validation passes when every required tool succeeds" {
	create_validation_fixture
	create_stub zsh 0
	create_stub fish 0
	create_stub shellcheck 0
	create_stub shdoc 0
	create_stub shfmt 0

	run_fixture_static --strict ""
	assert_success
	assert_output_contains "mode: strict"
	assert_output_contains "failed: 0"
	assert_output_contains "skipped: 0"
	assert_output_contains "status: passed"
}

@test "runner returns nonzero when an available static tool fails" {
	create_validation_fixture
	create_stub shellcheck 7

	run_fixture_static --local "zsh,fish,shdoc,shfmt"
	assert_failure
	assert_output_contains "ShellCheck"
	assert_output_contains "status: failed"
}

@test "runner returns nonzero when shdoc fails" {
	create_validation_fixture
	create_stub shdoc 8

	run_fixture_static --local "zsh,fish,shellcheck,shfmt"
	assert_failure
	assert_output_contains "shdoc parsing"
	assert_output_contains "status: failed"
}

@test "runner returns nonzero when shfmt fails" {
	create_validation_fixture
	create_stub shfmt 9

	run_fixture_static --local "zsh,fish,shellcheck,shdoc"
	assert_failure
	assert_output_contains "shfmt formatting"
	assert_output_contains "status: failed"
}

@test "runner returns nonzero when Bats is unavailable" {
	create_validation_fixture

	run env \
		MANTLE_TEST_ROOT="${FIXTURE_ROOT}" \
		MANTLE_RUNNER_TEST_UNAVAILABLE_TOOLS="bats" \
		"${RUNNER}" unit
	assert_failure
	assert_output_contains "Bats 1.5+ is required"
	assert_output_contains "status: failed"
}

@test "runner rejects an empty Bats suite" {
	create_validation_fixture

	run env MANTLE_TEST_ROOT="${FIXTURE_ROOT}" "${RUNNER}" unit
	assert_failure
	assert_output_contains "unit suite contains no Bats tests"
	assert_output_contains "status: failed"
}

@test "bin mode runs every maintained bin test" {
	create_validation_fixture
	printf '%s\n' '#!/usr/bin/env bats' '@test "bin fixture passes" { true; }' \
		>"${FIXTURE_ROOT}/tests/bin/fixture.bats"
	printf '%s\n' '#!/usr/bin/env bats' '@test "unmapped regression passes" { true; }' \
		>"${FIXTURE_ROOT}/tests/bin/regression.bats"

	run env MANTLE_TEST_ROOT="${FIXTURE_ROOT}" "${RUNNER}" bin
	assert_success
	assert_output_contains "bin fixture passes"
	assert_output_contains "unmapped regression passes"
	assert_output_contains "Bats bin suite"
	assert_output_contains "status: passed"
}

@test "runner rejects unsupported options and extra modes" {
	run "${RUNNER}" --unsupported
	assert_status 64
	assert_output_contains "unknown option"
	run "${RUNNER}" unit integration
	assert_status 64
	assert_output_contains "only one mode"
}

@test "runner rejects relative validation roots" {
	run env MANTLE_TEST_ROOT=relative "${RUNNER}" static
	assert_status 64
	assert_output_contains "must be an absolute path"
}

@test "runner rejects an existing file that is not a Bats test" {
	local unsupported_file="${TEST_HOME}/not-a-test.txt"
	printf 'this must not be silently accepted\n' >"${unsupported_file}"
	run "${RUNNER}" "${unsupported_file}"
	assert_status 64
	assert_output_contains "unknown mode or Bats test file"
}

@test "runner includes maintained release and validation scripts in static checks" {
	create_validation_fixture
	printf '%s\n' 'if then' >"${FIXTURE_ROOT}/scripts/broken.sh"
	run_fixture_static --local
	assert_failure
	assert_output_contains "scripts/broken.sh"
}

@test "source discovery preserves literal paths without evaluating file names" {
	create_validation_fixture
	local literal_name='space $(touch runner-injection-marker);literal.sh'
	printf '%s\n' '#!/usr/bin/env bash' 'exit 0' \
		>"${FIXTURE_ROOT}/init/${literal_name}"
	cd "${TEST_HOME}"
	run_fixture_static --local
	assert_success
	[[ ! -e "${TEST_HOME}/runner-injection-marker" ]]
}
