#!/usr/bin/env bats
# Integration tests for module behavior (xdg, privacy, update-checks, etc.).

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
}

teardown() {
	teardown_isolated_home
}

# ---------------------------------------------------------------------------
# XDG module
# ---------------------------------------------------------------------------

@test "xdg module sets XDG_CONFIG_HOME to default" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			printf '%s\n' \"\${XDG_CONFIG_HOME}\"
		"
	assert_success
	assert_output_contains "${TEST_HOME}/.config"
}

@test "xdg module preserves caller-provided absolute XDG_CONFIG_HOME" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		XDG_CONFIG_HOME="${TEST_HOME}/custom-config" \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			printf '%s\n' \"\${XDG_CONFIG_HOME}\"
		"
	assert_success
	assert_output_contains "${TEST_HOME}/custom-config"
}

@test "xdg module replaces relative XDG_CONFIG_HOME with default and warns" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		XDG_CONFIG_HOME="relative/path" \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg 2>&1
			printf '%s\n' \"\${XDG_CONFIG_HOME}\"
		" 2>&1
	assert_output_contains "must be absolute"
	assert_output_contains "${TEST_HOME}/.config"
}

@test "xdg module sets XDG_RUNTIME_DIR to an absolute path" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			printf '%s\n' \"\${XDG_RUNTIME_DIR}\"
		"
	assert_success
	[[ "${lines[0]}" == /* ]]
}

# ---------------------------------------------------------------------------
# Privacy module
# ---------------------------------------------------------------------------

@test "privacy module exports DO_NOT_TRACK=1 by default" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			mantle_load_module privacy
			printf '%s\n' \"\${DO_NOT_TRACK}\"
		"
	assert_success
	assert_output_contains "1"
}

@test "privacy module is skipped when MANTLE_DISABLE_TELEMETRY=0" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		MANTLE_DISABLE_TELEMETRY=0 \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			mantle_load_module privacy
			printf '%s\n' \"\${DO_NOT_TRACK:-unset}\"
		"
	assert_success
	assert_output_contains "unset"
}

@test "privacy module is independent from update-check suppression" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			mantle_load_module privacy
			# HOMEBREW_NO_AUTO_UPDATE should NOT be set by privacy alone
			printf '%s\n' \"\${HOMEBREW_NO_AUTO_UPDATE:-unset}\"
		"
	assert_success
	assert_output_contains "unset"
}

# ---------------------------------------------------------------------------
# Update-checks module contract
# ---------------------------------------------------------------------------

@test "update-checks module is not loaded by default" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${MANTLE_LOADED_MODULES}\"
		"
	assert_success
	assert_output_not_contains "update-checks"
}

@test "update-checks module loads only when MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS=1" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS=1 \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${MANTLE_LOADED_MODULES}\"
		"
	assert_success
	assert_output_contains "update-checks"
}

@test "update-checks module sets HOMEBREW_NO_AUTO_UPDATE when loaded" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS=1 \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${HOMEBREW_NO_AUTO_UPDATE:-unset}\"
		"
	assert_success
	assert_output_contains "1"
}

@test "HOMEBREW_NO_AUTO_UPDATE is unset by default" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${HOMEBREW_NO_AUTO_UPDATE:-unset}\"
		"
	assert_success
	assert_output_contains "unset"
}

@test "update-check suppression does not affect telemetry policy" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		MANTLE_DISABLE_AUTOMATIC_UPDATE_CHECKS=1 \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf 'telemetry=%s\n' \"\${DO_NOT_TRACK:-unset}\"
		"
	assert_success
	assert_output_contains "telemetry=1"
}

@test "update-checks module rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/modules/update-checks.sh"
	assert_status 64
}

@test "privacy module rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/modules/privacy.sh"
	assert_status 64
}

# ---------------------------------------------------------------------------
# Migration-safe XDG tooling, caches, and history
# ---------------------------------------------------------------------------

@test "tooling preserves legacy state and reports every pending migration" {
	mkdir -p "${TEST_HOME}/.cargo/bin" "${TEST_HOME}/go" "${TEST_HOME}/.android"

	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'cargo=%s\n' \"\${CARGO_HOME:-legacy}\"
			printf 'go=%s\n' \"\${GOPATH:-legacy}\"
			printf 'android=%s\n' \"\${ANDROID_USER_HOME:-legacy}\"
			printf 'path=%s\n' \"\${PATH}\"
			printf 'warnings=%s\n' \"\${MANTLE_XDG_MIGRATION_WARNINGS:-}\"
		"
	assert_success
	assert_output_contains "cargo=legacy"
	assert_output_contains "go=legacy"
	assert_output_contains "android=legacy"
	assert_output_contains "${TEST_HOME}/.cargo/bin"
	assert_output_contains "CARGO_HOME"
	assert_output_contains "GOPATH"
	assert_output_contains "ANDROID_USER_HOME"
}

@test "tooling selects audited XDG roots for a fresh home" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'ansible=%s\n' \"\${ANSIBLE_HOME}\"
			printf 'docker=%s\n' \"\${DOCKER_CONFIG}\"
			printf 'dart=%s\n' \"\${DART_DATA_HOME}\"
			printf 'sdk=%s\n' \"\${ANDROID_HOME:-unset}\"
			printf 'sdk_root=%s\n' \"\${ANDROID_SDK_ROOT:-unset}\"
			printf 'flutter=%s\n' \"\${FLUTTER_HOME:-unset}\"
		"
	assert_success
	assert_output_contains "ansible=${TEST_HOME}/.local/share/ansible"
	assert_output_contains "docker=${TEST_HOME}/.config/docker"
	assert_output_contains "dart=${TEST_HOME}/.local/share/dart"
	assert_output_contains "sdk=unset"
	assert_output_contains "sdk_root=unset"
	assert_output_contains "flutter=unset"
}

@test "cache preserves an existing npm cache until migration" {
	mkdir -p "${TEST_HOME}/.npm"

	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'cache=%s\n' \"\${NPM_CONFIG_CACHE:-legacy}\"
			printf 'warnings=%s\n' \"\${MANTLE_XDG_MIGRATION_WARNINGS:-}\"
		"
	assert_success
	assert_output_contains "cache=legacy"
	assert_output_contains "NPM_CONFIG_CACHE"
}

@test "tooling preserves a legacy npmrc until its XDG file exists" {
	printf '%s\n' 'fund=false' >"${TEST_HOME}/.npmrc"

	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			source '${MANTLE_ROOT}/.shellrc'
			printf 'config=%s\n' \"\${NPM_CONFIG_USERCONFIG:-legacy}\"
			printf 'warnings=%s\n' \"\${MANTLE_XDG_MIGRATION_WARNINGS:-}\"
		"
	assert_success
	assert_output_contains "config=legacy"
	assert_output_contains "NPM_CONFIG_USERCONFIG"
}

@test "history preserves legacy Bash history instead of silently splitting it" {
	printf '%s\n' 'existing command' >"${TEST_HOME}/.bash_history"

	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			MANTLE_INTERACTIVE=1
			MANTLE_SHELL_NAME=bash
			export MANTLE_ROOT MANTLE_INTERACTIVE MANTLE_SHELL_NAME
			source '${MANTLE_ROOT}/lib/modules.sh'
			mantle_load_module xdg
			mantle_load_module history
			printf 'history=%s\n' \"\${HISTFILE}\"
			printf 'warnings=%s\n' \"\${MANTLE_XDG_MIGRATION_WARNINGS:-}\"
		"
	assert_success
	assert_output_contains "history=${TEST_HOME}/.bash_history"
	assert_output_contains "HISTFILE"
}

@test "history retains the prior Mantle history file and an explicit caller override" {
	mkdir -p "${XDG_STATE_HOME}/history/bash"
	touch "${XDG_STATE_HOME}/history/bash/history"
	# shellcheck disable=SC2016 # History assertions run in the isolated child shell.
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb MANTLE_ROOT="${MANTLE_ROOT}" \
		/bin/bash --noprofile --norc -c '
            source "$MANTLE_ROOT/modules/xdg.sh" || exit $?
            MANTLE_INTERACTIVE=1
            MANTLE_SHELL_NAME=bash
            source "$MANTLE_ROOT/modules/history.sh" || exit $?
            test "$HISTFILE" = "$XDG_STATE_HOME/history/bash/history" || exit 91
            HISTFILE="$HOME/caller-history"
            source "$MANTLE_ROOT/modules/history.sh" || exit $?
            test "$HISTFILE" = "$HOME/caller-history" || exit 92
            printf "existing-history-preserved\n"
        '
	assert_success
	assert_output_contains "existing-history-preserved"
}
