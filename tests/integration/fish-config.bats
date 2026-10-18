#!/usr/bin/env bats
# Native Fish configuration parses data without invoking Bash or Python.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	require_fish
	FISH_CONFIG_SHELL="$(command -v fish)"
	FISH_CONFIG_FILE="${TEST_HOME}/mantle.conf"
}

teardown() {
	if declare -F teardown_isolated_home >/dev/null; then teardown_isolated_home; fi
	return 0
}

# @description Resolve native Fish settings before executing trusted assertions.
# @arg $1 string Trusted Fish commands.
# @arg $@ string Optional environment overrides.
_fish_config() {
	local commands="${1:?}"
	shift
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" \
		MANTLE_CONFIG_FILE="${FISH_CONFIG_FILE}" MANTLE_CREATE_XDG_DIRECTORIES=0 \
		PATH="${PATH}" LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" TERM=dumb GEM_PATH=/fixture/gems \
		"$@" "${FISH_CONFIG_SHELL}" --no-config --interactive --command \
		'source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status; eval $argv[1]' "${commands}"
}

@test "Fish literal config selects inherited profiles and keeps minimal capabilities authoritative" {
	printf "schema_version=1\nprofile=ci\naliases.safe=true\n" >"${FISH_CONFIG_FILE}"
	_fish_config '
printf "profile=%s safe=%s source=%s\n" "$MANTLE_ACTIVE_PROFILE" "$MANTLE_POLICY_ALIASES_SAFE" "$MANTLE_PROFILE_SOURCE"
contains -- "$MANTLE_ROOT/runtime/shells/fish/functions" $fish_function_path; and exit 1
functions --query mkcd; and exit 1
test -z "$GEM_HOME"
'
	assert_success
	assert_output_contains "profile=ci safe=true source=config:"
}

@test "Fish config applies environment overrides and focused aliases without the legacy corpus" {
	printf "schema_version=1\nprofile=ci\naliases.safe=false\naliases.legacy=false\naliases.safety=true\n" >"${FISH_CONFIG_FILE}"
	_fish_config '
printf "profile=%s safe=%s\n" "$MANTLE_ACTIVE_PROFILE" "$MANTLE_POLICY_ALIASES_SAFE"
functions --query mkcd; or exit 1
functions --query cp; or exit 1
abbr --query gs; and exit 1
ls -d "$HOME" >/dev/null; or exit 1
functions --query ls; and exit 1
mantle_config_print_effective aliases.safe
' MANTLE_PROFILE=interactive MANTLE_ENABLE_SAFE_ALIASES=yes
	assert_success
	assert_output_contains "profile=interactive safe=true"
	assert_output_contains "environment:MANTLE_ENABLE_SAFE_ALIASES"
}

@test "Fish config rejects malformed schema keys values and executable text without evaluating it" {
	local content
	for content in \
		"profile=ci" \
		$'schema_version=2\nprofile=ci' \
		$'schema_version=1\nprofile=missing' \
		$'schema_version=1\naliases.safe=maybe' \
		$'schema_version=1\naliases.safe=true\naliases.safe=false' \
		$'schema_version=1\nunknown=true' \
		"schema_version=1
aliases.safe=\$(touch ${TEST_HOME}/must-not-run)"; do
		printf "%s\n" "${content}" >"${FISH_CONFIG_FILE}"
		_fish_config "true" MANTLE_PROFILE=ci
		assert_status 78
		assert_file_not_exists "${TEST_HOME}/must-not-run"
	done
}

@test "Fish config distinguishes an absent default from a missing explicit file" {
	_fish_config "true"
	assert_status 66
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" MANTLE_PROFILE=ci \
		PATH="${PATH}" LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" MANTLE_CREATE_XDG_DIRECTORIES=0 \
		"${FISH_CONFIG_SHELL}" --no-config --command \
		'source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status; printf "file=%s source=%s\n" "$MANTLE_CONFIG_FILE_STATUS" "$MANTLE_PROFILE_SOURCE"'
	assert_success
	assert_output_contains "file=absent source=environment:MANTLE_PROFILE"
}

@test "Fish config matches Bash effective settings and provenance for literal values" {
	printf "schema_version=1\nprofile=interactive\naliases.legacy=false\naliases.safe=true\nhistory=false\nupdates.suppress_checks=on\npresentation=share-safe\n" >"${FISH_CONFIG_FILE}"
	_fish_config "mantle_config_print_effective"
	assert_success
	local fish_effective="${output}"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" MANTLE_CONFIG_FILE="${FISH_CONFIG_FILE}" \
		MANTLE_CREATE_XDG_DIRECTORIES=0 PATH="${PATH}" \
		/bin/bash --noprofile --norc -c 'source "$MANTLE_ROOT/.shellrc" || exit $?; mantle_config_print_effective'
	assert_success
	[[ "${output}" == "${fish_effective}" ]]
}

@test "Fish config preserves derived profile provenance in nested shells" {
	printf "schema_version=1\nprofile=interactive\n" >"${FISH_CONFIG_FILE}"
	_fish_config '
source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status
printf "schema_version=1\nprofile=ci\n" >"$MANTLE_CONFIG_FILE"
"$FISH_CONFIG_SHELL" --no-config --command '\''source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status; printf "child=%s source=%s\n" "$MANTLE_ACTIVE_PROFILE" "$MANTLE_PROFILE_SOURCE"'\''
' FISH_CONFIG_SHELL="${FISH_CONFIG_SHELL}"
	assert_success
	assert_output_contains "child=ci source=config:"
}

@test "Fish config accepts a final line without newline and retains native history choices" {
	printf "schema_version=1\nprofile=interactive\nhistory=false" >"${FISH_CONFIG_FILE}"
	_fish_config 'printf "history=%s\n" "$MANTLE_POLICY_HISTORY"; test "$fish_history" = user-session' fish_history=user-session
	assert_success
	assert_output_contains "history=false"
}

@test "Fish config keeps update suppression separate and rejects invalid explicit policy" {
	printf "schema_version=1\nprofile=ci\nupdates.suppress_checks=true\n" >"${FISH_CONFIG_FILE}"
	_fish_config 'test "$HOMEBREW_NO_AUTO_UPDATE" = 1; and test "$MANTLE_POLICY_SUPPRESS_UPDATE_CHECKS" = true'
	assert_success
	_fish_config "true" MANTLE_ENABLE_SAFE_ALIASES=invalid
	assert_status 78
}

@test "Fish config rejects reserved experimental behavior before runtime mutation" {
	local value
	for value in true on yes 1; do
		printf "schema_version=1\nprofile=workstation\nexperimental=%s\n" "${value}" >"${FISH_CONFIG_FILE}"
		_fish_config "true" XDG_BIN_HOME="${TEST_HOME}/must-not-create" MANTLE_CREATE_XDG_DIRECTORIES=1 MANTLE_ENABLE_EXPERIMENTAL=false
		assert_status 78
		assert_output_contains "experimental behavior is unavailable"
		[[ ! -e "${TEST_HOME}/must-not-create" ]]

		printf "schema_version=1\nprofile=workstation\nexperimental=false\n" >"${FISH_CONFIG_FILE}"
		_fish_config "true" XDG_BIN_HOME="${TEST_HOME}/must-not-create" MANTLE_CREATE_XDG_DIRECTORIES=1 MANTLE_ENABLE_EXPERIMENTAL="${value}"
		assert_status 78
		assert_output_contains "experimental behavior is unavailable"
		[[ ! -e "${TEST_HOME}/must-not-create" ]]
	done
}
