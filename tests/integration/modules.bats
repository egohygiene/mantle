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
