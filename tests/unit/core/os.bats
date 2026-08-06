#!/usr/bin/env bats
# Unit tests for lib/core/os.sh

setup() {
	load '../../test_helper/common'
	load '../../test_helper/assertions'
	setup_isolated_home
}

teardown() {
	teardown_isolated_home
}

@test "os.sh exports MANTLE_OS_FAMILY" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		printf '%s\n' \"\${MANTLE_OS_FAMILY}\"
	"
	assert_success
	[[ -n "${lines[0]}" ]]
}

@test "os.sh exports MANTLE_OS_ARCH" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		printf '%s\n' \"\${MANTLE_OS_ARCH}\"
	"
	assert_success
	[[ -n "${lines[0]}" ]]
}

@test "os.sh exports MANTLE_IS_WSL" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		printf '%s\n' \"\${MANTLE_IS_WSL}\"
	"
	assert_success
	[[ "${lines[0]}" == "0" || "${lines[0]}" == "1" ]]
}

@test "os.sh exports MANTLE_IS_CONTAINER" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		printf '%s\n' \"\${MANTLE_IS_CONTAINER}\"
	"
	assert_success
	[[ "${lines[0]}" == "0" || "${lines[0]}" == "1" ]]
}

@test "mantle_os_detect prints linux on Linux" {
	if [[ "$(uname -s)" != "Linux" ]]; then skip "not Linux"; fi
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		mantle_os_detect
	"
	assert_success
	assert_output_contains "linux"
}

@test "mantle_os_detect prints darwin on macOS" {
	if [[ "$(uname -s)" != "Darwin" ]]; then skip "not macOS"; fi
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		mantle_os_detect
	"
	assert_success
	assert_output_contains "darwin"
}

@test "mantle_os_name prints a non-empty label" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		mantle_os_name
	"
	assert_success
	[[ -n "${lines[0]}" ]]
}

@test "os.sh MANTLE_OS_FAMILY is one of darwin linux windows unknown" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		printf '%s\n' \"\${MANTLE_OS_FAMILY}\"
	"
	assert_success
	case "${lines[0]}" in
	darwin | linux | windows | unknown) ;;
	*) return 1 ;;
	esac
}

@test "os.sh is idempotent (double source)" {
	run /bin/bash --noprofile --norc -c "
		MANTLE_ROOT='${MANTLE_ROOT}'
		export MANTLE_ROOT
		source '${MANTLE_ROOT}/lib/core/os.sh'
		source '${MANTLE_ROOT}/lib/core/os.sh'
		printf 'ok\n'
	"
	assert_success
	assert_output_contains "ok"
}
