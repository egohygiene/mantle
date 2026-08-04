#!/usr/bin/env bats
# Contract tests — source-safety (direct execution rejection).

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
}

@test ".shellrc rejects direct execution in Bash" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/.shellrc"
	assert_status 64
	assert_output_contains "must be sourced"
}

@test "init/init.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/init/init.sh"
	assert_status 64
}

@test "init/bootstrap.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/init/bootstrap.sh"
	assert_status 64
}

@test "init/load-core.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/init/load-core.sh"
	assert_status 64
}

@test "lib/modules.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/modules.sh"
	assert_status 64
}

@test "lib/core/core.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/core/core.sh"
	assert_status 64
}

@test "lib/core/guards.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/core/guards.sh"
	assert_status 64
}

@test "lib/core/logging.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/core/logging.sh"
	assert_status 64
}

@test "lib/core/os.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/core/os.sh"
	assert_status 64
}

@test "lib/install/checksum.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/install/checksum.sh"
	assert_status 64
}

@test "lib/install/download.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/install/download.sh"
	assert_status 64
}

@test "lib/install/archive.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/lib/install/archive.sh"
	assert_status 64
}

@test "modules/privacy.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/modules/privacy.sh"
	assert_status 64
}

@test "modules/update-checks.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/modules/update-checks.sh"
	assert_status 64
}

@test "modules/xdg.sh rejects direct execution" {
	run /bin/bash --noprofile --norc "${MANTLE_ROOT}/modules/xdg.sh"
	assert_status 64
}

@test "every shell file in lib/install/ rejects direct execution" {
	local failed=0
	for f in "${MANTLE_ROOT}/lib/install"/*.sh; do
		[[ -f "${f}" ]] || continue
		run /bin/bash --noprofile --norc "${f}"
		if [[ "${status}" -ne 64 ]]; then
			printf "Expected exit 64 from direct execution of %s, got %d\n" "${f}" "${status}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}
