#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Read-only configuration, environment, path, and completion interfaces.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	load '../test_helper/stubs'
	setup_isolated_home
	setup_stub_dir
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

# @description Run one CLI request in a clean environment without activating Mantle.
# @arg $@ string Public Mantle arguments.
_runtime_cli() {
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${STUB_DIR}:${PATH}" TERM=dumb "${MANTLE_ROOT}/bin/mantle" "$@"
}

@test "runtime CLI help works without Python or other optional tools" {
	local tool command_name
	for tool in bash dirname basename readlink; do
		ln -s "$(command -v "${tool}")" "${STUB_DIR}/${tool}"
	done
	for command_name in config env path completion; do
		run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" \
			PATH="${STUB_DIR}" "${MANTLE_ROOT}/bin/mantle" "${command_name}" --help
		assert_success
		assert_output_contains "Usage: mantle ${command_name}"
	done
}

@test "config list-profiles describes the existing six-profile graph" {
	_runtime_cli config list-profiles
	assert_success
	[[ "${#lines[@]}" -eq 7 ]]
	[[ "${lines[0]}" == $'profile\tparents\tcapabilities' ]]
	assert_output_contains $'workstation\tinteractive\ttooling:workstation'
	assert_output_contains $'full\tworkstation:container:ci\t-'
	assert_output_not_contains "standard"
}

@test "config defaults preserve workstation and explain profile policy provenance" {
	_runtime_cli config show
	assert_success
	assert_output_contains "schema_version=1"
	assert_output_contains "profile=workstation"
	assert_output_contains "history=true"
	_runtime_cli config explain aliases.safe
	assert_success
	assert_output_contains "profile:workstation"
	assert_output_contains "interactive"
	assert_file_not_exists "${XDG_CONFIG_HOME}/mantle/config.conf"
}

@test "config precedence retains explicit environment policy over literal file values" {
	local config_file="${TEST_HOME}/settings.conf"
	printf "%s\n" "schema_version=1" "profile=ci" "history=false" >"${config_file}"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${STUB_DIR}:${PATH}" MANTLE_CONFIG_FILE="${config_file}" \
		MANTLE_PROFILE=interactive MANTLE_ENABLE_HISTORY=true \
		"${MANTLE_ROOT}/bin/mantle" config show
	assert_success
	assert_output_contains "profile=interactive"
	assert_output_contains "history=true"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" \
		PATH="${STUB_DIR}:${PATH}" MANTLE_CONFIG_FILE="${config_file}" \
		MANTLE_ENABLE_HISTORY=true "${MANTLE_ROOT}/bin/mantle" config explain history
	assert_success
	assert_output_contains "environment:MANTLE_ENABLE_HISTORY"
}

@test "config validates explicit relative files as data and never executes their contents" {
	local config_file="${TEST_HOME}/literal.conf"
	printf "%s\n" "schema_version=1" "profile=container" >"${config_file}"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${PATH}" \
		/bin/bash -c 'cd "$HOME"; "$MANTLE_ROOT/bin/mantle" config validate literal.conf'
	assert_success
	assert_output_contains "status: loaded"
	assert_output_contains "profile: container"
	printf "%s\n" "schema_version=1" 'history=$(touch forbidden-config-command)' >"${config_file}"
	_runtime_cli config validate "${config_file}"
	assert_status 78
	assert_file_not_exists "${TEST_HOME}/forbidden-config-command"
	assert_file_not_exists "${MANTLE_ROOT}/forbidden-config-command"
}

@test "config reports missing files invalid profiles and unknown settings meaningfully" {
	_runtime_cli config validate "${TEST_HOME}/missing.conf"
	assert_status 66
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${PATH}" \
		MANTLE_PROFILE=unknown-profile "${MANTLE_ROOT}/bin/mantle" config show
	assert_status 64
	_runtime_cli config explain unknown.setting
	assert_status 64
}

@test "env exposes only allowlisted state and shell quoting preserves literal values" {
	local literal_value=$'literal value; $(touch forbidden-env-command)\nsecond line'
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${PATH}" \
		AWS_SECRET_ACCESS_KEY="private-sentinel-value" PRIVATE_FIXTURE="private-extra-value" \
		MANTLE_ACTIVE_PROFILE=ci MANTLE_PROFILE_CAPABILITIES="core:ci" \
		MANTLE_XDG_MIGRATION_WARNINGS="${literal_value}" \
		"${MANTLE_ROOT}/bin/mantle" env --shell
	assert_success
	assert_output_contains "export MANTLE_ACTIVE_PROFILE=ci"
	assert_output_contains "export MANTLE_PROFILE_CAPABILITIES=core:ci"
	assert_output_not_contains "private-sentinel-value"
	assert_output_not_contains "private-extra-value"
	printf "%s\n" "${output}" >"${TEST_HOME}/exports.sh"
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" EXPECTED_LITERAL="${literal_value}" \
		/bin/bash -c 'cd "$HOME"; source "$HOME/exports.sh"; [[ "$MANTLE_XDG_MIGRATION_WARNINGS" == "$EXPECTED_LITERAL" ]]'
	assert_success
	assert_file_not_exists "${TEST_HOME}/forbidden-env-command"
}

@test "path reports installation locations and preserves empty PATH entry positions" {
	_runtime_cli path --root
	assert_success
	[[ "${output}" == "${MANTLE_ROOT}" ]]
	_runtime_cli path --bin
	assert_success
	[[ "${output}" == "${MANTLE_ROOT}/bin" ]]
	run env -i MANTLE_ROOT="${MANTLE_ROOT}" PATH="/first::/second:" /bin/bash -c '
		/bin/bash "$MANTLE_ROOT/libexec/mantle/commands/path.sh" --entries
		printf "END\n"
	'
	assert_success
	[[ "${output}" == $'/first\n\n/second\n\nEND' ]]
}

@test "completion definitions parse in the target shell and include current commands" {
	local shell_name
	for shell_name in bash zsh fish; do
		_runtime_cli completion "${shell_name}"
		assert_success
		assert_output_contains "hls-download"
		assert_output_contains "archive"
		assert_output_contains "--assurance"
		printf "%s\n" "${output}" >"${TEST_HOME}/completion.${shell_name}"
		if command -v "${shell_name}" >/dev/null 2>&1; then
			case "${shell_name}" in
			fish) run fish --no-execute "${TEST_HOME}/completion.${shell_name}" ;;
			*) run "${shell_name}" -n "${TEST_HOME}/completion.${shell_name}" ;;
			esac
			assert_success
		fi
	done
}

@test "completion discovers added commands and installers without a maintained list" {
	local fixture="${TEST_HOME}/completion-root"
	mkdir -p "${fixture}/bin" "${fixture}/config" "${fixture}/libexec/mantle/commands" \
		"${fixture}/libexec/mantle/installers"
	cp "${MANTLE_ROOT}/bin/mantle" "${fixture}/bin/mantle"
	cp "${MANTLE_ROOT}/config/profiles.tsv" "${fixture}/config/profiles.tsv"
	cp "${MANTLE_ROOT}/libexec/mantle/commands/completion.sh" "${fixture}/libexec/mantle/commands/"
	printf "#!/bin/sh\nexit 99\n" >"${fixture}/libexec/mantle/commands/added-fixture.sh"
	printf "#!/bin/sh\nexit 99\n" >"${fixture}/libexec/mantle/installers/fixture-tool.sh"
	chmod 0755 "${fixture}/bin/mantle" "${fixture}/libexec/mantle/commands/"*.sh \
		"${fixture}/libexec/mantle/installers/fixture-tool.sh"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${fixture}" PATH="${PATH}" \
		"${fixture}/bin/mantle" completion bash
	assert_success
	assert_output_contains "added-fixture"
	assert_output_contains "fixture-tool"
	printf "%s\n" "${output}" >"${TEST_HOME}/generated-completion.sh"
	run /bin/bash --noprofile --norc -c '
		source "$1"
		COMP_WORDS=(mantle added-); COMP_CWORD=1; _mantle_completion
		[[ "${COMPREPLY[*]}" == added-fixture ]] || exit 1
		COMP_WORDS=(mantle install fixture-); COMP_CWORD=2; _mantle_completion
		[[ "${COMPREPLY[*]}" == fixture-tool ]]
	' _ "${TEST_HOME}/generated-completion.sh"
	assert_success
}

@test "runtime CLI commands reject unsupported arguments" {
	local command_name
	local private_argument=$'--private-option-fixture\033[31m\nsecret-value'
	for command_name in config env path completion; do
		_runtime_cli "${command_name}" "${private_argument}"
		assert_status 64
		assert_output_not_contains "private-option-fixture"
		assert_output_not_contains $'\033'
	done
}

@test "config usage diagnostics do not echo arbitrary arguments or terminal controls" {
	local private_argument=$'private-config-fixture\033[31m\nsecret-value'
	_runtime_cli config "${private_argument}"
	assert_status 64
	assert_output_not_contains "private-config-fixture"
	assert_output_not_contains $'\033'
	_runtime_cli config explain "${private_argument}"
	assert_status 64
	assert_output_not_contains "private-config-fixture"
	assert_output_not_contains $'\033'
	_runtime_cli config validate "${TEST_HOME}/${private_argument}"
	assert_status 66
	assert_output_not_contains "private-config-fixture"
	assert_output_not_contains $'\033'
}
