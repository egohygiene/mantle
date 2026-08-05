#!/usr/bin/env bats
# Unit tests for lib/core/guards.sh

setup() {
	load '../../test_helper/common'
	load '../../test_helper/assertions'
	setup_isolated_home
	setup_stub_dir
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

_load_guards() {
	MANTLE_ROOT="${MANTLE_ROOT}"
	export MANTLE_ROOT
	# shellcheck source=/dev/null
	source "${MANTLE_ROOT}/lib/core/guards.sh"
}

# ---------------------------------------------------------------------------
# mantle_guard_has_command
# ---------------------------------------------------------------------------

@test "mantle_guard_has_command returns 0 for an available command" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		mantle_guard_has_command ls && printf 'yes\n' || printf 'no\n'
	"
	assert_success
	assert_output_contains "yes"
}

@test "mantle_guard_has_command returns 1 for a missing command" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		mantle_guard_has_command __totally_nonexistent_cmd_xyz__ \
			&& printf 'yes\n' || printf 'no\n'
	"
	assert_output_contains "no"
}

@test "mantle_guard_has_command returns 64 when called with no arguments" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		mantle_guard_has_command
		printf '%d\n' \$?
	"
	assert_output_contains "64"
}

# ---------------------------------------------------------------------------
# mantle_guard_file_exists
# ---------------------------------------------------------------------------

@test "mantle_guard_file_exists returns 0 for an existing file" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		mantle_guard_file_exists '${MANTLE_ROOT}/.shellrc' \
			&& printf 'yes\n' || printf 'no\n'
	"
	assert_success
	assert_output_contains "yes"
}

@test "mantle_guard_file_exists returns 1 for a missing path" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		mantle_guard_file_exists '/no/such/file' \
			&& printf 'yes\n' || printf 'no\n'
	"
	assert_output_contains "no"
}

# ---------------------------------------------------------------------------
# mantle_guard_directory_exists
# ---------------------------------------------------------------------------

@test "mantle_guard_directory_exists returns 0 for an existing directory" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		mantle_guard_directory_exists '${MANTLE_ROOT}' \
			&& printf 'yes\n' || printf 'no\n'
	"
	assert_success
	assert_output_contains "yes"
}

@test "mantle_guard_directory_exists returns 1 for a missing directory" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		mantle_guard_directory_exists '/no/such/directory' \
			&& printf 'yes\n' || printf 'no\n'
	"
	assert_output_contains "no"
}

# ---------------------------------------------------------------------------
# mantle_file_is_executable
# ---------------------------------------------------------------------------

@test "mantle_file_is_executable returns 0 for bin/mantle" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		mantle_file_is_executable '${MANTLE_ROOT}/bin/mantle' \
			&& printf 'yes\n' || printf 'no\n'
	"
	assert_success
	assert_output_contains "yes"
}

# ---------------------------------------------------------------------------
# mantle_file_has_shebang
# ---------------------------------------------------------------------------

@test "mantle_file_has_shebang returns 0 for a file with a shebang" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		mantle_file_has_shebang '${MANTLE_ROOT}/bin/mantle' \
			&& printf 'yes\n' || printf 'no\n'
	"
	assert_success
	assert_output_contains "yes"
}

@test "guards.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/core/guards.sh"
	assert_status 64
}

@test "guards.sh is idempotent (double source)" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		printf 'ok\n'
	"
	assert_success
	assert_output_contains "ok"
}
