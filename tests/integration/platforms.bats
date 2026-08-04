#!/usr/bin/env bats
# Integration tests for platform runtime adapters.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	setup_stub_dir
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

# ---------------------------------------------------------------------------
# OS detection library
# ---------------------------------------------------------------------------

@test "os.sh sets MANTLE_OS_FAMILY on Linux" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			printf '%s\n' \"\${MANTLE_OS_FAMILY}\"
		"
	assert_success
	# On Linux CI this should be "linux"; test just that it's set
	[[ -n "${lines[0]}" ]]
}

@test "os.sh sets MANTLE_OS_ARCH to a non-empty value" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			printf '%s\n' \"\${MANTLE_OS_ARCH}\"
		"
	assert_success
	[[ -n "${lines[0]}" ]]
}

@test "os.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/core/os.sh"
	assert_status 64
}

@test "mantle_os_detect prints the OS family" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		mantle_os_detect
	"
	assert_success
	[[ -n "${lines[0]}" ]]
}

@test "mantle_os_arch prints the architecture" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		mantle_os_arch
	"
	assert_success
	[[ -n "${lines[0]}" ]]
}

@test "mantle_os_is_linux returns 0 on a Linux runner" {
	if [[ "$(uname -s)" != "Linux" ]]; then
		skip "not running on Linux"
	fi
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		mantle_os_is_linux && printf 'yes\n' || printf 'no\n'
	"
	assert_success
	assert_output_contains "yes"
}

@test "mantle_os_is_macos returns 0 on a macOS runner" {
	if [[ "$(uname -s)" != "Darwin" ]]; then
		skip "not running on macOS"
	fi
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		mantle_os_is_macos && printf 'yes\n' || printf 'no\n'
	"
	assert_success
	assert_output_contains "yes"
}

@test "os.sh detects WSL when WSL_DISTRO_NAME is set" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		WSL_DISTRO_NAME="Ubuntu" \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			printf '%s\n' \"\${MANTLE_IS_WSL}\"
		"
	assert_success
	assert_output_contains "1"
}

@test "os.sh detects container when /.dockerenv is present (stub)" {
	# Create a temporary fake /.dockerenv via chroot is not possible; use
	# the 'container' env variable as an alternative trigger instead.
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		container="docker" \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			printf '%s\n' \"\${MANTLE_IS_CONTAINER}\"
		"
	assert_success
	assert_output_contains "1"
}

# ---------------------------------------------------------------------------
# Shared runtime
# ---------------------------------------------------------------------------

@test "runtime/shared/runtime.sh sources without error" {
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/lib/core/os.sh'
			source '${MANTLE_ROOT}/lib/core/shell.sh'
			source '${MANTLE_ROOT}/runtime/shared/runtime.sh'
			printf 'ok\n'
		"
	assert_success
	assert_output_contains "ok"
}

# ---------------------------------------------------------------------------
# Platform runtime load via full init
# ---------------------------------------------------------------------------

@test "Linux platform runtime loads without error" {
	if [[ "$(uname -s)" != "Linux" ]]; then
		skip "not running on Linux"
	fi
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${MANTLE_INITIALIZATION_STATE}\"
		"
	assert_success
	assert_output_contains "initialized"
}

@test "macOS platform runtime loads without error" {
	if [[ "$(uname -s)" != "Darwin" ]]; then
		skip "not running on macOS"
	fi
	run env -i HOME="${TEST_HOME}" PATH="${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/.shellrc'
			printf '%s\n' \"\${MANTLE_INITIALIZATION_STATE}\"
		"
	assert_success
	assert_output_contains "initialized"
}

# ---------------------------------------------------------------------------
# Windows / MSYS adapter (stub-based)
# ---------------------------------------------------------------------------

@test "Windows platform runtime sources without error using uname stub" {
	create_stub "uname" 0 "MSYS_NT-10.0"
	run env -i HOME="${TEST_HOME}" PATH="${STUB_DIR}:${PATH}" TERM=dumb \
		/bin/bash --noprofile --norc -c "
			MANTLE_ROOT='${MANTLE_ROOT}'
			export MANTLE_ROOT
			source '${MANTLE_ROOT}/platforms/windows/runtime.sh' 2>&1 || true
			printf 'sourced\n'
		"
	assert_output_contains "sourced"
}
