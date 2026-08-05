#!/usr/bin/env bats
# Contract tests — repository layout and file organization.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
}

# ---------------------------------------------------------------------------
# Public executables live in bin/
# ---------------------------------------------------------------------------

@test "bin/mantle is executable" {
	assert_file_executable "${MANTLE_ROOT}/bin/mantle"
}

@test "bin/ contains only expected public executables" {
	local unexpected=0
	for f in "${MANTLE_ROOT}/bin"/*; do
		[[ -f "${f}" ]] || continue
		case "${f##*/}" in
			mantle) ;;
			*)
				printf "Unexpected file in bin/: %s\n" "${f}" >&2
				unexpected=1
				;;
		esac
	done
	[[ "${unexpected}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Private executables live under libexec/
# ---------------------------------------------------------------------------

@test "libexec/mantle/commands/ files are executable" {
	local failed=0
	for f in "${MANTLE_ROOT}/libexec/mantle/commands"/*.sh; do
		[[ -f "${f}" ]] || continue
		if [[ ! -x "${f}" ]]; then
			printf "Not executable: %s\n" "${f}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

@test "libexec/mantle/installers/ files are executable" {
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

# ---------------------------------------------------------------------------
# Source-only libraries are not marked executable
# ---------------------------------------------------------------------------

@test "lib/core/ source libraries are not executable" {
	local failed=0
	for f in "${MANTLE_ROOT}/lib/core"/*.sh; do
		[[ -f "${f}" ]] || continue
		if [[ -x "${f}" ]]; then
			printf "Unexpectedly executable library: %s\n" "${f}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

@test "lib/bash/ source libraries are not executable" {
	local failed=0
	for f in "${MANTLE_ROOT}/lib/bash"/*.sh; do
		[[ -f "${f}" ]] || continue
		if [[ -x "${f}" ]]; then
			printf "Unexpectedly executable library: %s\n" "${f}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

@test "lib/install/ source libraries are not executable" {
	local failed=0
	for f in "${MANTLE_ROOT}/lib/install"/*.sh; do
		[[ -f "${f}" ]] || continue
		if [[ -x "${f}" ]]; then
			printf "Unexpectedly executable library: %s\n" "${f}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

@test "modules/ source files are not executable" {
	local failed=0
	for f in "${MANTLE_ROOT}/modules"/*.sh; do
		[[ -f "${f}" ]] || continue
		if [[ -x "${f}" ]]; then
			printf "Unexpectedly executable module: %s\n" "${f}" >&2
			failed=1
		fi
	done
	[[ "${failed}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# No junk files
# ---------------------------------------------------------------------------

@test "no .DS_Store files in tracked source directories" {
	local count
	count=$(find "${MANTLE_ROOT}" \
		\( -name ".git" -prune \) -o \
		-name ".DS_Store" -print 2>/dev/null | wc -l | tr -d ' ')
	[[ "${count}" -eq 0 ]]
}

@test "no __MACOSX directories in tracked source" {
	local count
	count=$(find "${MANTLE_ROOT}" \
		\( -name ".git" -prune \) -o \
		-name "__MACOSX" -type d -print 2>/dev/null | wc -l | tr -d ' ')
	[[ "${count}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Required files exist
# ---------------------------------------------------------------------------

@test ".shellrc exists" {
	assert_file_exists "${MANTLE_ROOT}/.shellrc"
}

@test "bin/mantle exists" {
	assert_file_exists "${MANTLE_ROOT}/bin/mantle"
}

@test "init/init.sh exists" {
	assert_file_exists "${MANTLE_ROOT}/init/init.sh"
}

@test "init/bootstrap.sh exists" {
	assert_file_exists "${MANTLE_ROOT}/init/bootstrap.sh"
}

@test "lib/modules.sh exists" {
	assert_file_exists "${MANTLE_ROOT}/lib/modules.sh"
}
