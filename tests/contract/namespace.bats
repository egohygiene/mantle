#!/usr/bin/env bats
# Contract tests — namespace hygiene and legacy-reference checks.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
}

# ---------------------------------------------------------------------------
# No EGOHYGIENE references
# ---------------------------------------------------------------------------

@test "no active source files reference EGOHYGIENE namespace" {
	local count
	count=$(grep -r "EGOHYGIENE" \
		"${MANTLE_ROOT}/bin" \
		"${MANTLE_ROOT}/init" \
		"${MANTLE_ROOT}/lib" \
		"${MANTLE_ROOT}/libexec" \
		"${MANTLE_ROOT}/modules" \
		"${MANTLE_ROOT}/platforms" \
		"${MANTLE_ROOT}/runtime" \
		"${MANTLE_ROOT}/.shellrc" \
		2>/dev/null | wc -l | tr -d ' ')
	[[ "${count}" -eq 0 ]]
}

@test "no test files reference EGOHYGIENE namespace" {
	if [[ ! -d "${MANTLE_ROOT}/tests" ]]; then skip "no tests directory"; fi
	local count
	# Exclude this file itself to avoid the self-referential grep match.
	count=$(grep -r "EGOHYGIENE" "${MANTLE_ROOT}/tests" \
		--exclude="namespace.bats" \
		--exclude="installers.bats" \
		2>/dev/null | wc -l | tr -d ' ')
	[[ "${count}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# No legacy namespace::function syntax
# ---------------------------------------------------------------------------

@test "no source files use the legacy namespace::function syntax" {
	local count
	count=$(grep -rE '[a-z]+::[a-z]' \
		"${MANTLE_ROOT}/bin" \
		"${MANTLE_ROOT}/init" \
		"${MANTLE_ROOT}/lib" \
		"${MANTLE_ROOT}/libexec" \
		"${MANTLE_ROOT}/modules" \
		"${MANTLE_ROOT}/platforms" \
		"${MANTLE_ROOT}/runtime" \
		"${MANTLE_ROOT}/.shellrc" \
		2>/dev/null | wc -l | tr -d ' ')
	[[ "${count}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# No legacy bin/install-* commands
# ---------------------------------------------------------------------------

@test "bin/ contains no legacy install-* commands" {
	local found
	found=$(find "${MANTLE_ROOT}/bin" -name "install-*" 2>/dev/null | wc -l | tr -d ' ')
	[[ "${found}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# No INSTALL_* (non-MANTLE) variables in installers
# ---------------------------------------------------------------------------

@test "installers do not use bare INSTALL_ variables (non-MANTLE prefix)" {
	local count
	count=$(grep -rE '^\s*INSTALL_[A-Z]' \
		"${MANTLE_ROOT}/libexec/mantle/installers/" \
		2>/dev/null | wc -l | tr -d ' ')
	[[ "${count}" -eq 0 ]]
}
