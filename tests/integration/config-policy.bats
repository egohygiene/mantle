#!/usr/bin/env bats
# shellcheck disable=SC2016 # Trusted child-shell code and hostile config fixtures remain literal.
# Literal configuration and interactive policy through the public runtimes.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	POLICY_FILE="${TEST_HOME}/.config/mantle/config.conf"
	mkdir -p "$(dirname "${POLICY_FILE}")"
}

teardown() {
	teardown_isolated_home
}

# @description Run trusted assertions after public startup in an isolated native shell.
# @arg $1 string Bash or Zsh.
# @arg $2 string Interactive or noninteractive mode.
# @arg $3 string Trusted shell assertions.
# @arg $@ string Additional environment assignments.
_policy_run() {
	local shell_name="${1:?}" mode="${2:?}" commands="${3:?}"
	local shell_binary script_path="${TEST_HOME}/policy-check.sh"
	local -a shell_arguments
	shift 3
	shell_binary="$(command -v "${shell_name}" || true)"
	[[ -n "${shell_binary}" ]] || skip "${shell_name} is not available"
	if [[ "${shell_name}" == "bash" ]]; then
		shell_arguments=(--noprofile --norc)
	else
		shell_arguments=(--no-rcs)
	fi
	[[ "${mode}" != "interactive" ]] || shell_arguments+=(-i)
	{
		printf '%s\n' 'source "$MANTLE_ROOT/.shellrc" || exit $?'
		printf '%s\n' "${commands}"
	} >"${script_path}"
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" MANTLE_ROOT="${MANTLE_ROOT}" \
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" TERM=dumb "$@" \
		"${shell_binary}" "${shell_arguments[@]}" "${script_path}"
}

@test "config policy defaults preserve the workstation legacy corpus" {
	_policy_run bash noninteractive '
        printf "%s|%s|%s|%s|%s\n" "$MANTLE_ACTIVE_PROFILE" "$MANTLE_PROFILE_SOURCE" "$MANTLE_POLICY_ALIASES_LEGACY" "$MANTLE_POLICY_ALIASES_SAFE" "$MANTLE_POLICY_HISTORY"
        test "$MANTLE_CONFIG_FILE_STATUS" = absent || exit 91
        test "$MANTLE_LOADED_MODULES" = xdg:privacy:cache:tooling:environment || exit 92
    '
	assert_success
	assert_line_contains 'workstation|default|true|false|true'
}

@test "config policy can select focused aliases while disabling the legacy corpus and history" {
	printf '%s\n' schema_version=1 profile=interactive aliases.legacy=false aliases.safe=true history=false >"${POLICY_FILE}"
	_policy_run bash interactive '
        test "$MANTLE_LOADED_MODULES" = xdg:privacy:environment:aliases-safe || exit 91
        command -v mantle_mkcd >/dev/null || exit 92
        ! command -v mantle_public_ip >/dev/null || exit 93
        ! alias rm >/dev/null 2>&1 || exit 94
        printf "focused-safe-policy\n"
    '
	assert_success
	assert_output_contains 'focused-safe-policy'
}

@test "config policy focused network system and safety groups are independently selected" {
	printf '%s\n' schema_version=1 profile=interactive aliases.legacy=false aliases.network=true aliases.system=true aliases.safety=true history=false >"${POLICY_FILE}"
	_policy_run bash interactive '
        test "$MANTLE_LOADED_MODULES" = xdg:privacy:environment:aliases-network:aliases-system:aliases-safety || exit 91
        command -v mantle_public_ip >/dev/null || exit 92
        command -v mantle_system_update >/dev/null || exit 93
        ! command -v mantle_mkcd >/dev/null || exit 94
        alias rm
    '
	assert_success
	assert_output_contains 'command rm -i'
}

@test "config policy flags cannot add interactive behavior to a minimal base profile" {
	printf '%s\n' schema_version=1 profile=ci aliases.legacy=true aliases.safe=true history=true >"${POLICY_FILE}"
	_policy_run bash interactive '
        test "$MANTLE_LOADED_MODULES" = xdg:privacy:environment || exit 91
        test -z "${NODE_REPL_HISTORY+x}" || exit 92
        printf "capabilities-remain-authoritative\n"
    '
	assert_success
	assert_output_contains 'capabilities-remain-authoritative'
}

@test "config policy disabling the legacy corpus also disables desktop platform aliases" {
	mkdir "${TEST_HOME}/stub-bin"
	printf '%s\n' '#!/bin/sh' 'exit 0' >"${TEST_HOME}/stub-bin/ss"
	chmod 755 "${TEST_HOME}/stub-bin/ss"
	printf '%s\n' schema_version=1 profile=workstation aliases.legacy=false history=false >"${POLICY_FILE}"
	_policy_run bash interactive '
        ! alias ports >/dev/null 2>&1 || exit 91
        unset MANTLE_PLATFORM_LINUX_LOADED MANTLE_PLATFORM_DARWIN_LOADED
        source "$MANTLE_ROOT/platforms/linux/runtime.sh" || exit $?
        source "$MANTLE_ROOT/platforms/darwin/runtime.sh" || exit $?
        ! alias ports >/dev/null 2>&1 || exit 92
        ! alias show-hidden-files >/dev/null 2>&1 || exit 93
        ! command -v mantle_flush_dns >/dev/null 2>&1 || exit 94
        printf "desktop-alias-policy\n"
    ' PATH="${TEST_HOME}/stub-bin:${PATH}"
	assert_success
	assert_output_contains 'desktop-alias-policy'
}

@test "config policy environment overrides both the file profile and typed setting values" {
	printf '%s\n' schema_version=1 profile=interactive aliases.legacy=true aliases.safe=true history=true >"${POLICY_FILE}"
	_policy_run bash interactive '
        test "$MANTLE_ACTIVE_PROFILE" = core || exit 91
        test "$MANTLE_PROFILE_SOURCE" = environment:MANTLE_PROFILE || exit 92
        test "$MANTLE_POLICY_ALIASES_SAFE" = false || exit 93
        test "$MANTLE_POLICY_SOURCE_ALIASES_SAFE" = environment:MANTLE_ENABLE_SAFE_ALIASES || exit 94
        test "$MANTLE_POLICY_HISTORY" = false || exit 95
        test "$MANTLE_LOADED_MODULES" = xdg:privacy:environment || exit 96
        printf "environment-precedence\n"
    ' MANTLE_PROFILE=core MANTLE_ENABLE_SAFE_ALIASES=off MANTLE_ENABLE_HISTORY=0
	assert_success
	assert_output_contains 'environment-precedence'
}

@test "config policy rejects duplicate malformed unknown and unsupported schema records before modules" {
	local invalid
	for invalid in \
		$'schema_version=1\nprofile=ci\nprofile=core' \
		$'schema_version=2\nprofile=ci' \
		$'schema_version=1\nunknown.setting=true' \
		$'schema_version=1\naliases.safe="true"' \
		$'schema_version=1\n history=false' \
		$'schema_version=1\nno-equals'; do
		printf '%s\n' "${invalid}" >"${POLICY_FILE}"
		_policy_run bash noninteractive 'exit 99'
		assert_status 78
		assert_file_not_exists "${TEST_HOME}/.local/bin"
		assert_file_not_exists "${TEST_HOME}/.local/share/codex"
	done
}

@test "config policy literal values never execute command substitutions or backticks" {
	local invalid
	for invalid in 'history=$(touch${IFS}$HOME/forbidden)' 'history=`touch${IFS}$HOME/forbidden`'; do
		printf '%s\n' schema_version=1 "${invalid}" >"${POLICY_FILE}"
		_policy_run bash noninteractive 'exit 99'
		assert_status 78
		assert_file_not_exists "${TEST_HOME}/forbidden"
	done
}

@test "config policy diagnostics omit private values and terminal control characters" {
	local invalid
	for invalid in 'history=fixture-private-value' 'profile=fixture-private-value' $'\033[31mfixture-private-key=true'; do
		printf '%s\n' schema_version=1 "${invalid}" >"${POLICY_FILE}"
		_policy_run bash noninteractive 'exit 99'
		assert_status 78
		assert_output_not_contains 'fixture-private'
		assert_output_not_contains $'\033'
	done
	rm "${POLICY_FILE}"
	_policy_run bash noninteractive 'exit 99' MANTLE_PRESENTATION_MODE=$'\033[31mfixture-private-value'
	assert_status 78
	assert_output_contains 'MANTLE_PRESENTATION_MODE'
	assert_output_not_contains 'fixture-private'
	assert_output_not_contains $'\033'
}

@test "config policy validates a bad file profile even when the environment overrides it" {
	printf '%s\n' schema_version=1 profile=old-donor-profile >"${POLICY_FILE}"
	_policy_run bash noninteractive 'exit 99' MANTLE_PROFILE=ci
	assert_status 78
	assert_file_not_exists "${TEST_HOME}/.local/bin"
}

@test "config policy distinguishes missing explicit files and relative paths" {
	_policy_run bash noninteractive 'exit 99' MANTLE_CONFIG_FILE="${TEST_HOME}/missing.conf"
	assert_status 66
	_policy_run bash noninteractive 'exit 99' MANTLE_CONFIG_FILE=relative.conf
	assert_status 78
	assert_file_not_exists "${TEST_HOME}/.local/bin"
}

@test "config policy rejects invalid environment setting types before modules" {
	_policy_run bash noninteractive 'exit 99' MANTLE_ENABLE_HISTORY=maybe
	assert_status 78
	assert_file_not_exists "${TEST_HOME}/.local/bin"
	_policy_run bash noninteractive 'exit 99' MANTLE_PRESENTATION_MODE=unknown
	assert_status 78
	assert_file_not_exists "${TEST_HOME}/.local/bin"
}

@test "config policy rejects unavailable experimental behavior before modules" {
	local enabled
	for enabled in true yes on 1; do
		printf '%s\n' schema_version=1 "experimental=${enabled}" >"${POLICY_FILE}"
		_policy_run bash noninteractive 'exit 99'
		assert_status 78
		assert_output_contains 'experimental behavior is unavailable'
		assert_file_not_exists "${TEST_HOME}/.local/bin"
		rm "${POLICY_FILE}"
		_policy_run bash noninteractive 'exit 99' MANTLE_ENABLE_EXPERIMENTAL="${enabled}"
		assert_status 78
		assert_output_contains 'experimental behavior is unavailable'
		assert_file_not_exists "${TEST_HOME}/.local/bin"
	done
	printf '%s\n' schema_version=1 profile=ci experimental=false >"${POLICY_FILE}"
	_policy_run bash noninteractive 'test "$MANTLE_POLICY_EXPERIMENTAL" = false'
	assert_success
}

@test "config policy child commands reread file profiles instead of promoting a derived export" {
	printf '%s\n' schema_version=1 profile=core >"${POLICY_FILE}"
	_policy_run bash noninteractive '
        test "$MANTLE_PROFILE_SOURCE" = "config:$HOME/.config/mantle/config.conf" || exit 91
        printf "%s\n" schema_version=1 profile=ci >"$HOME/.config/mantle/config.conf"
        "$MANTLE_ROOT/bin/mantle" config show
    '
	assert_success
	assert_output_contains 'profile=ci'
}

@test "config policy child commands retain an original explicit profile override" {
	printf '%s\n' schema_version=1 profile=core >"${POLICY_FILE}"
	_policy_run bash noninteractive '
        printf "%s\n" schema_version=1 profile=ci >"$HOME/.config/mantle/config.conf"
        "$MANTLE_ROOT/bin/mantle" config show
    ' MANTLE_PROFILE=container
	assert_success
	assert_output_contains 'profile=container'
}

@test "config policy repeat startup remains idempotent and profile changes require a new shell" {
	printf '%s\n' schema_version=1 profile=interactive aliases.legacy=false aliases.safe=true >"${POLICY_FILE}"
	_policy_run bash interactive '
        before="$PATH|$MANTLE_LOADED_MODULES"
        source "$MANTLE_ROOT/.shellrc" || exit $?
        test "$before" = "$PATH|$MANTLE_LOADED_MODULES" || exit 91
        MANTLE_PROFILE=ci
        source "$MANTLE_ROOT/.shellrc"
    '
	assert_status 78
	assert_output_contains 'start a new shell'
}

@test "config policy Zsh preserves literal parsing focused groups and inherited profile provenance" {
	printf '%s\n' schema_version=1 profile=interactive aliases.legacy=false aliases.safe=true history=false >"${POLICY_FILE}"
	_policy_run zsh interactive '
        test "$MANTLE_LOADED_MODULES" = xdg:privacy:environment:aliases-safe || exit 91
        command -v mantle_mkcd >/dev/null || exit 92
        test "$MANTLE_POLICY_HISTORY" = false || exit 93
        printf "%s\n" schema_version=1 profile=ci >"$HOME/.config/mantle/config.conf"
        "$MANTLE_ROOT/bin/mantle" config show
    '
	assert_success
	assert_output_contains 'profile=ci'
	printf '%s\n' schema_version=1 'history=$(touch${IFS}$HOME/forbidden)' >"${POLICY_FILE}"
	_policy_run zsh noninteractive 'exit 99'
	assert_status 78
	assert_file_not_exists "${TEST_HOME}/forbidden"
}
