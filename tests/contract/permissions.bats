#!/usr/bin/env bats
# Contract tests — file permissions.
#
# These tests verify executable and non-executable constraints rather than
# exact mode bits, because umask and Git checkout settings vary across systems.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
}

@test "bin/mantle is executable" {
	assert_file_executable "${MANTLE_ROOT}/bin/mantle"
}

@test "libexec/mantle/commands/help.sh is executable" {
	assert_file_executable "${MANTLE_ROOT}/libexec/mantle/commands/help.sh"
}

@test "libexec/mantle/commands/version.sh is executable" {
	assert_file_executable "${MANTLE_ROOT}/libexec/mantle/commands/version.sh"
}

@test "libexec/mantle/commands/install.sh is executable" {
	assert_file_executable "${MANTLE_ROOT}/libexec/mantle/commands/install.sh"
}

@test "lib/core/core.sh is not executable" {
	assert_file_not_executable "${MANTLE_ROOT}/lib/core/core.sh"
}

@test "lib/core/guards.sh is not executable" {
	assert_file_not_executable "${MANTLE_ROOT}/lib/core/guards.sh"
}

@test "lib/modules.sh is not executable" {
	assert_file_not_executable "${MANTLE_ROOT}/lib/modules.sh"
}

@test "modules/privacy.sh is not executable" {
	assert_file_not_executable "${MANTLE_ROOT}/modules/privacy.sh"
}

@test "modules/xdg.sh is not executable" {
	assert_file_not_executable "${MANTLE_ROOT}/modules/xdg.sh"
}

@test "every installer is executable" {
	local failed=0
	for f in "${MANTLE_ROOT}/libexec/mantle/installers"/*.sh; do
		[[ -f "${f}" ]] || continue
		if [[ ! -x "${f}" ]]; then
			printf "Not executable: %s\n" "${f}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}
