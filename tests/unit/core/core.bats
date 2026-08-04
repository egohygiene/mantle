#!/usr/bin/env bats
# Unit tests for lib/core/core.sh — public mantle_core_* API

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

_load_core() {
	cat <<'BASH'
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source "${MANTLE_ROOT}/lib/core/core.sh"
BASH
}

_bash_core() {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/core.sh'
		$*
	"
}

# ---------------------------------------------------------------------------
# mantle_core_platform
# ---------------------------------------------------------------------------

@test "mantle_core_platform returns a known platform name" {
	_bash_core "mantle_core_platform"
	assert_success
	case "${lines[0]}" in
		linux | macos | freebsd | netbsd | openbsd | windows | cygwin | unknown) ;;
		*) return 1 ;;
	esac
}

# ---------------------------------------------------------------------------
# mantle_core_has_command
# ---------------------------------------------------------------------------

@test "mantle_core_has_command returns 0 for ls" {
	_bash_core "mantle_core_has_command ls && printf 'yes\n' || printf 'no\n'"
	assert_success
	assert_output_contains "yes"
}

@test "mantle_core_has_command returns 1 for a missing command" {
	_bash_core "mantle_core_has_command __missing_cmd__ && printf 'yes\n' || printf 'no\n'"
	assert_output_contains "no"
}

@test "mantle_core_has_command returns 64 with no arguments" {
	_bash_core "mantle_core_has_command; printf '%d\n' \$?"
	assert_output_contains "64"
}

# ---------------------------------------------------------------------------
# mantle_core_path_contains
# ---------------------------------------------------------------------------

@test "mantle_core_path_contains returns 0 when directory is on PATH" {
	_bash_core "
		export PATH='/usr/bin:/bin'
		mantle_core_path_contains '/usr/bin' && printf 'yes\n' || printf 'no\n'
	"
	assert_success
	assert_output_contains "yes"
}

@test "mantle_core_path_contains returns 1 when directory is not on PATH" {
	_bash_core "
		export PATH='/usr/bin:/bin'
		mantle_core_path_contains '/totally/not/there' && printf 'yes\n' || printf 'no\n'
	"
	assert_output_contains "no"
}

# ---------------------------------------------------------------------------
# mantle_core_path_prepend
# ---------------------------------------------------------------------------

@test "mantle_core_path_prepend adds directory at the front of PATH" {
	_bash_core "
		export PATH='/usr/bin:/bin'
		mantle_core_path_prepend '/new/dir'
		printf '%s\n' \"\${PATH%%:*}\"
	"
	assert_success
	assert_output_contains "/new/dir"
}

@test "mantle_core_path_prepend does not duplicate an already-present directory" {
	_bash_core "
		export PATH='/first:/second'
		mantle_core_path_prepend '/first'
		count=0
		IFS=: read -ra parts <<< \"\${PATH}\"
		for p in \"\${parts[@]}\"; do [[ \"\$p\" == '/first' ]] && ((count++)); done
		printf '%d\n' \"\${count}\"
	"
	assert_success
	assert_output_contains "1"
}

# ---------------------------------------------------------------------------
# mantle_core_path_append
# ---------------------------------------------------------------------------

@test "mantle_core_path_append adds directory at the end of PATH" {
	_bash_core "
		export PATH='/usr/bin:/bin'
		mantle_core_path_append '/new/last'
		printf '%s\n' \"\${PATH##*:}\"
	"
	assert_success
	assert_output_contains "/new/last"
}

# ---------------------------------------------------------------------------
# mantle_core_ensure_directory
# ---------------------------------------------------------------------------

@test "mantle_core_ensure_directory creates a directory" {
	local new_dir="${TEST_HOME}/some/new/dir"
	_bash_core "
		mantle_core_ensure_directory '${new_dir}'
	"
	assert_success
	assert_dir_exists "${new_dir}"
}

@test "mantle_core_ensure_directory succeeds when directory already exists" {
	local existing_dir="${TEST_HOME}/already"
	mkdir -p "${existing_dir}"
	_bash_core "
		mantle_core_ensure_directory '${existing_dir}'
	"
	assert_success
}

@test "mantle_core_ensure_directory returns 64 with no arguments" {
	_bash_core "mantle_core_ensure_directory; printf '%d\n' \$?"
	assert_output_contains "64"
}

# ---------------------------------------------------------------------------
# mantle_core_directory_is_empty
# ---------------------------------------------------------------------------

@test "mantle_core_directory_is_empty returns 0 for an empty directory" {
	local empty_dir="${TEST_HOME}/empty"
	mkdir -p "${empty_dir}"
	_bash_core "
		mantle_core_directory_is_empty '${empty_dir}' && printf 'yes\n' || printf 'no\n'
	"
	assert_success
	assert_output_contains "yes"
}

@test "mantle_core_directory_is_empty returns 1 for a non-empty directory" {
	local dir="${TEST_HOME}/nonempty"
	mkdir -p "${dir}"
	touch "${dir}/file"
	_bash_core "
		mantle_core_directory_is_empty '${dir}' && printf 'yes\n' || printf 'no\n'
	"
	assert_output_contains "no"
}

# ---------------------------------------------------------------------------
# mantle_core_is_root
# ---------------------------------------------------------------------------

@test "mantle_core_is_root returns 1 for a non-root user in CI" {
	if [[ "$(id -u)" -eq 0 ]]; then skip "running as root"; fi
	_bash_core "mantle_core_is_root && printf 'root\n' || printf 'nonroot\n'"
	assert_success
	assert_output_contains "nonroot"
}

# ---------------------------------------------------------------------------
# core.sh meta-tests
# ---------------------------------------------------------------------------

@test "core.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/core/core.sh"
	assert_status 64
}

@test "core.sh is idempotent (double source)" {
	_bash_core "
		source '${MANTLE_ROOT}/lib/core/core.sh'
		printf 'ok\n'
	"
	assert_success
	assert_output_contains "ok"
}
