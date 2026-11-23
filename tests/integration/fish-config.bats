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
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
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
		XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
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
		MANTLE_CREATE_XDG_DIRECTORIES=0 PATH="${PATH}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
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

@test "Fish preserves legacy tool roots and PATH when empty XDG targets exist" {
	printf '%s\n' 'schema_version=1' >"$FISH_CONFIG_FILE"
	mkdir -p "$TEST_HOME/.cargo/bin" "$TEST_HOME/.rustup" "$TEST_HOME/.pyenv/bin"
	mkdir -p "$TEST_HOME/.asdf/bin" "$TEST_HOME/.asdf/shims" "$TEST_HOME/.volta/bin" "$TEST_HOME/go/bin" "$TEST_HOME/.gem/specs"
	mkdir -p "$TEST_HOME/.local/share/cargo/bin" "$TEST_HOME/.local/share/rustup" "$TEST_HOME/.local/share/pyenv/bin"
	mkdir -p "$TEST_HOME/.local/share/asdf" "$TEST_HOME/.local/share/volta" "$TEST_HOME/.local/share/go" "$TEST_HOME/.cache/gem/specs"
	_fish_config '
		for variable in CARGO_HOME RUSTUP_HOME PYENV_ROOT ASDF_DATA_DIR VOLTA_HOME GOPATH GEM_SPEC_CACHE
			set -q $variable; and exit 91
			contains -- "$variable" (string split : -- "$MANTLE_XDG_MIGRATION_WARNINGS"); or exit 92
		end
		contains -- "$HOME/.cargo/bin" $PATH; or exit 93
		contains -- "$HOME/.pyenv/bin" $PATH; or exit 94
		contains -- "$HOME/go/bin" $PATH; or exit 95
		contains -- "$HOME/.local/share/cargo/bin" $PATH; and exit 96
		printf "legacy-paths-preserved\n"
	' MANTLE_PROFILE=workstation XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
	assert_success
	assert_output_contains "legacy-paths-preserved"
}

@test "Fish preserves broken legacy links and honors explicit tool selections" {
	printf '%s\n' 'schema_version=1' >"$FISH_CONFIG_FILE"
	ln -s "$TEST_HOME/missing-cargo" "$TEST_HOME/.cargo"
	mkdir -p "$TEST_HOME/.local/share/cargo/bin"
	_fish_config '
		set -q CARGO_HOME; and exit 91
		contains -- CARGO_HOME (string split : -- "$MANTLE_XDG_MIGRATION_WARNINGS"); or exit 92
	' MANTLE_PROFILE=workstation XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
	assert_success
	_fish_config '
		test "$CARGO_HOME" = "$HOME/.local/share/cargo"; or exit 91
		contains -- "$CARGO_HOME/bin" $PATH; or exit 92
		contains -- CARGO_HOME (string split : -- "$MANTLE_XDG_MIGRATION_WARNINGS"); and exit 93
		true
	' MANTLE_PROFILE=workstation CARGO_HOME="$TEST_HOME/.local/share/cargo" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
	assert_success
	[[ -L "$TEST_HOME/.cargo" ]]
}

@test "Fish fresh activation clears inherited warnings and exports XDG data search paths" {
	printf '%s\n' 'schema_version=1' >"$FISH_CONFIG_FILE"
	_fish_config '
		test "$CARGO_HOME" = "$HOME/.local/share/cargo"; or exit 91
		test -z "$MANTLE_XDG_MIGRATION_WARNINGS"; or exit 92
		printf "data-dirs=%s\n" "$XDG_DATA_DIRS"
	' MANTLE_PROFILE=workstation MANTLE_XDG_MIGRATION_WARNINGS=STALE_PARENT_WARNING XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
	assert_success
	assert_output_contains "data-dirs=/usr/local/share:/usr/share"
}

@test "Fish normalizes relative and empty XDG roots without writing in startup cwd" {
	printf '%s\n' 'schema_version=1' >"$FISH_CONFIG_FILE"
	mkdir -p "$TEST_HOME/work"
	run env -i HOME="$TEST_HOME" PATH="$PATH" MANTLE_ROOT="$MANTLE_ROOT" TERM=dumb \
		MANTLE_CREATE_XDG_DIRECTORIES=1 XDG_CONFIG_HOME=relative-config XDG_CACHE_HOME=relative-cache \
		XDG_DATA_HOME=relative-data XDG_STATE_HOME= XDG_BIN_HOME=relative-bin XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
		GEM_PATH=/fixture/gems "$FISH_CONFIG_SHELL" --no-config --command '
		cd "$HOME/work"; or exit 91
		source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status
		test "$XDG_CONFIG_HOME" = "$HOME/.config"; or exit 92
		test "$XDG_CACHE_HOME" = "$HOME/.cache"; or exit 93
		test "$XDG_DATA_HOME" = "$HOME/.local/share"; or exit 94
		test "$XDG_STATE_HOME" = "$HOME/.local/state"; or exit 95
		test "$XDG_BIN_HOME" = "$HOME/.local/bin"; or exit 96
		for relative_path in relative-config relative-cache relative-data relative-bin
			test -e "$HOME/work/$relative_path"; and exit 97
		end
		true
	'
	assert_success
	assert_output_contains "must be absolute"
	[[ ! -e "$TEST_HOME/work/relative-config" ]]
	[[ ! -e "$TEST_HOME/work/relative-bin" ]]
}

@test "Fish preserves absolute XDG roots and ordinary directory creation opt-out" {
	printf '%s\n' 'schema_version=1' >"$FISH_CONFIG_FILE"
	mkdir -p "$TEST_HOME/selected-runtime"
	chmod 755 "$TEST_HOME/selected-runtime"
	# Native Fish can create XDG paths before --command, even with --no-config.
	# Compare one process before/after Mantle, then prove the detector catches mkdir.
	run env -i HOME="$TEST_HOME" MANTLE_ROOT="$MANTLE_ROOT" MANTLE_CONFIG_FILE="$FISH_CONFIG_FILE" \
		MANTLE_PROFILE=ci MANTLE_CREATE_XDG_DIRECTORIES=0 PATH="$PATH" \
		LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" TERM=dumb GEM_PATH=/fixture/gems \
		XDG_CONFIG_HOME="$TEST_HOME/selected/config" XDG_CACHE_HOME="$TEST_HOME/selected/cache" \
		XDG_DATA_HOME="$TEST_HOME/selected/data" XDG_STATE_HOME="$TEST_HOME/selected/state" \
		XDG_BIN_HOME="$TEST_HOME/selected/bin" XDG_RUNTIME_DIR="$TEST_HOME/selected-runtime" \
		"$FISH_CONFIG_SHELL" --no-config --interactive --command '
		function __mantle_test_selected_paths --argument-names snapshot_file
			if test -e "$HOME/selected"; or test -L "$HOME/selected"
				command find "$HOME/selected" -print | command env LC_ALL=C sort >"$snapshot_file"
				set -l scan_status $pipestatus
				test "$scan_status[1]" -eq 0; and test "$scan_status[2]" -eq 0
			else
				printf "%s" "" >"$snapshot_file"
			end
		end

		set -q MANTLE_FISH_INITIALIZATION_STATE; and exit 81
		set -l state_was_present 0
		test -e "$XDG_STATE_HOME"; and set state_was_present 1
		set -l bin_was_present 0
		test -e "$XDG_BIN_HOME"; and set bin_was_present 1
		__mantle_test_selected_paths "$HOME/native-selected-paths"; or exit 82
		printf "native-fish-selected-paths:\n"
		command cat "$HOME/native-selected-paths"; or exit 83

		source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status
		test "$XDG_CONFIG_HOME" = "$HOME/selected/config"; or exit 91
		test "$XDG_CACHE_HOME" = "$HOME/selected/cache"; or exit 92
		test "$XDG_DATA_HOME" = "$HOME/selected/data"; or exit 93
		test "$XDG_STATE_HOME" = "$HOME/selected/state"; or exit 94
		test "$XDG_BIN_HOME" = "$HOME/selected/bin"; or exit 95
		test "$XDG_RUNTIME_DIR" = "$HOME/selected-runtime"; or exit 96
		test -d "$XDG_RUNTIME_DIR"; or exit 97
		__mantle_test_selected_paths "$HOME/mantle-selected-paths"; or exit 98
		if not command cmp -s "$HOME/native-selected-paths" "$HOME/mantle-selected-paths"
			printf "Mantle added paths beyond native Fish startup:\n" >&2
			command diff -u "$HOME/native-selected-paths" "$HOME/mantle-selected-paths" >&2
			exit 99
		end
		if test "$state_was_present" -eq 0; and test -e "$XDG_STATE_HOME"
			exit 100
		end
		if test "$bin_was_present" -eq 0; and test -e "$XDG_BIN_HOME"
			exit 101
		end
		printf "mantle-optout-preserved-native-baseline\n"

		# A deliberate fixture mutation must be detected by the same inventory.
		test -e "$XDG_BIN_HOME/mantle-optout-probe"; and exit 102
		command mkdir -p -- "$XDG_BIN_HOME/mantle-optout-probe"; or exit 103
		__mantle_test_selected_paths "$HOME/mkdir-selected-paths"; or exit 104
		command cmp -s "$HOME/native-selected-paths" "$HOME/mkdir-selected-paths"; and exit 105
		printf "mkdir-control-detected\n"
	'
	assert_success
	assert_output_contains "native-fish-selected-paths:"
	assert_output_contains "mantle-optout-preserved-native-baseline"
	assert_output_contains "mkdir-control-detected"
	run find "$TEST_HOME/selected-runtime" -prune -perm 0700
	assert_success
	assert_output_contains "$TEST_HOME/selected-runtime"
}

@test "Fish creates a mandatory private runtime directory with ordinary creation disabled" {
	printf '%s\n' 'schema_version=1' >"$FISH_CONFIG_FILE"
	_fish_config '
		test -d "$XDG_RUNTIME_DIR"; or exit 91
		test -O "$XDG_RUNTIME_DIR"; or exit 92
		printf "runtime=%s\n" "$XDG_RUNTIME_DIR"
	' MANTLE_PROFILE=ci XDG_RUNTIME_DIR="$TEST_HOME/new-runtime"
	assert_success
	assert_output_contains "runtime=$TEST_HOME/new-runtime"
	run find "$TEST_HOME/new-runtime" -prune -perm 0700
	assert_success
	assert_output_contains "$TEST_HOME/new-runtime"
}

@test "Fish rejects runtime symbolic links before changing target permissions" {
	printf '%s\n' 'schema_version=1' >"$FISH_CONFIG_FILE"
	mkdir -p "$TEST_HOME/runtime-target"
	chmod 755 "$TEST_HOME/runtime-target"
	ln -s "$TEST_HOME/runtime-target" "$TEST_HOME/runtime-link"
	_fish_config true MANTLE_PROFILE=ci XDG_RUNTIME_DIR="$TEST_HOME/runtime-link"
	assert_failure
	assert_output_contains "must not be a symbolic link"
	run find "$TEST_HOME/runtime-target" -prune -perm 0755
	assert_success
	assert_output_contains "$TEST_HOME/runtime-target"
}

@test "Fish repeated public sourcing keeps current migration diagnostics" {
	printf '%s\n' 'schema_version=1' >"$FISH_CONFIG_FILE"
	mkdir -p "$TEST_HOME/.cargo"
	_fish_config '
		set -l previous_warnings "$MANTLE_XDG_MIGRATION_WARNINGS"
		source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status
		test "$MANTLE_XDG_MIGRATION_WARNINGS" = "$previous_warnings"; or exit 91
		contains -- CARGO_HOME (string split : -- "$previous_warnings"); or exit 92
		functions --query __mantle_fish_set_xdg; and exit 93
		true
	' MANTLE_PROFILE=workstation XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
	assert_success
}

@test "Fish shadows relative universal runtime state without writing in startup cwd" {
	mkdir -p "$TEST_HOME/work" "$TEST_HOME/private-temp" "$TEST_HOME/stubs"
	printf '%s\n' '#!/bin/sh' 'printf 18446744073709551614' >"$TEST_HOME/stubs/id"
	chmod 755 "$TEST_HOME/stubs/id"
	run env -i HOME="$TEST_HOME" PATH="$TEST_HOME/stubs:$PATH" MANTLE_ROOT="$MANTLE_ROOT" \
		MANTLE_PROFILE=ci MANTLE_CREATE_XDG_DIRECTORIES=0 TMPDIR="$TEST_HOME/private-temp" TERM=dumb \
		"$FISH_CONFIG_SHELL" --no-config --command '
		set --universal XDG_RUNTIME_DIR relative-runtime
		set --universal MANTLE_XDG_MIGRATION_WARNINGS STALE_UNIVERSAL_WARNING
		cd "$HOME/work"; or exit 91
		source "$MANTLE_ROOT/runtime/shells/fish/runtime.fish"; or exit $status
		test "$XDG_RUNTIME_DIR" = "$TMPDIR/mantle-runtime-18446744073709551614"; or exit 92
		test -d "$XDG_RUNTIME_DIR"; or exit 93
		test -O "$XDG_RUNTIME_DIR"; or exit 94
		test -z "$MANTLE_XDG_MIGRATION_WARNINGS"; or exit 95
		test -e "$HOME/work/relative-runtime"; and exit 96
		true
	'
	assert_success
	assert_output_contains "must be absolute"
	[[ ! -e "$TEST_HOME/work/relative-runtime" ]]
	[[ -d "$TEST_HOME/private-temp/mantle-runtime-18446744073709551614" ]]
}
