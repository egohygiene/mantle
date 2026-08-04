#!/usr/bin/env bats
# Contract tests — public API inventory.
# Every mantle_* function in lib/core/ and lib/bash/ should have at least
# one call site in the test suite.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
}

# ---------------------------------------------------------------------------
# Core library public functions are defined after sourcing
# ---------------------------------------------------------------------------

@test "lib/core/core.sh exports expected public functions" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/core.sh'
		declare -f mantle_core_platform >/dev/null && printf 'ok\n'
		declare -f mantle_core_has_command >/dev/null && printf 'ok\n'
		declare -f mantle_core_path_contains >/dev/null && printf 'ok\n'
		declare -f mantle_core_path_prepend >/dev/null && printf 'ok\n'
		declare -f mantle_core_path_append >/dev/null && printf 'ok\n'
		declare -f mantle_core_ensure_directory >/dev/null && printf 'ok\n'
		declare -f mantle_core_is_root >/dev/null && printf 'ok\n'
	"
	assert_success
	local ok_count
	ok_count="$(printf "%s\n" "${lines[@]}" | grep -c "^ok$")"
	[[ "${ok_count}" -ge 7 ]]
}

@test "lib/core/guards.sh exports expected public functions" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/guards.sh'
		declare -f mantle_guard_has_command >/dev/null && printf 'ok\n'
		declare -f mantle_guard_file_exists >/dev/null && printf 'ok\n'
		declare -f mantle_guard_directory_exists >/dev/null && printf 'ok\n'
		declare -f mantle_file_is_executable >/dev/null && printf 'ok\n'
		declare -f mantle_file_has_shebang >/dev/null && printf 'ok\n'
	"
	assert_success
	local ok_count
	ok_count="$(printf "%s\n" "${lines[@]}" | grep -c "^ok$")"
	[[ "${ok_count}" -ge 5 ]]
}

@test "lib/core/logging.sh exports expected public functions" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/logging.sh'
		declare -f mantle_log_info >/dev/null && printf 'ok\n'
		declare -f mantle_log_warn >/dev/null && printf 'ok\n'
		declare -f mantle_log_error >/dev/null && printf 'ok\n'
		declare -f mantle_log_success >/dev/null && printf 'ok\n'
		declare -f mantle_log_debug >/dev/null && printf 'ok\n'
	"
	assert_success
	local ok_count
	ok_count="$(printf "%s\n" "${lines[@]}" | grep -c "^ok$")"
	[[ "${ok_count}" -ge 5 ]]
}

@test "lib/core/os.sh exports expected public functions" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		declare -f mantle_os_detect >/dev/null && printf 'ok\n'
		declare -f mantle_os_arch >/dev/null && printf 'ok\n'
		declare -f mantle_os_is_macos >/dev/null && printf 'ok\n'
		declare -f mantle_os_is_linux >/dev/null && printf 'ok\n'
		declare -f mantle_os_is_wsl >/dev/null && printf 'ok\n'
		declare -f mantle_os_is_container >/dev/null && printf 'ok\n'
		declare -f mantle_os_name >/dev/null && printf 'ok\n'
	"
	assert_success
	local ok_count
	ok_count="$(printf "%s\n" "${lines[@]}" | grep -c "^ok$")"
	[[ "${ok_count}" -ge 7 ]]
}

@test "lib/modules.sh exports expected public functions" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/modules.sh'
		declare -f mantle_load_module >/dev/null && printf 'ok\n'
		declare -f mantle_list_loaded_modules >/dev/null && printf 'ok\n'
		declare -f mantle_is_module_loaded >/dev/null && printf 'ok\n'
	"
	assert_success
	local ok_count
	ok_count="$(printf "%s\n" "${lines[@]}" | grep -c "^ok$")"
	[[ "${ok_count}" -ge 3 ]]
}

@test "lib/install/checksum.sh exports expected public functions" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/install/runtime.sh'
		declare -f mantle_install_checksum_calculate >/dev/null && printf 'ok\n'
		declare -f mantle_install_checksum_verify >/dev/null && printf 'ok\n'
	"
	assert_success
	local ok_count
	ok_count="$(printf "%s\n" "${lines[@]}" | grep -c "^ok$")"
	[[ "${ok_count}" -ge 2 ]]
}
