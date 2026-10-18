#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Contract checks for current typed configuration and capability metadata.

setup() {
	load "../test_helper/common"
	load "../test_helper/assertions"
}

@test "runtime profile graph validates through the shared startup resolver" {
	run awk -v selected=full -f "${MANTLE_ROOT}/lib/core/profiles.awk" \
		"${MANTLE_ROOT}/config/profiles.tsv"
	assert_success
	[[ "${output}" == "core:interactive:tooling:workstation:container:ci" ]]
}

@test "settings registry keys and environment overrides are unique and typed" {
	run awk -F '\t' '
        NR == 1 { next }
        {
            if (NF != 6 || $1 !~ /^[a-z][a-z._]*$/ || keys[$1]++ ||
                $3 !~ /^MANTLE_[A-Z_]+$/ || overrides[$3]++ || $4 == "" || $6 == "") invalid = 1
            if ($2 != "boolean" && $2 != "enum") invalid = 1
            if ($2 == "boolean" && $4 != "true,false") invalid = 1
            if ($5 != "all" && $5 != "interactive" && $5 != "tty") invalid = 1
        }
        END { if (NR < 2) invalid = 1; exit invalid }
    ' "${MANTLE_ROOT}/config/settings.tsv"
	assert_success
}

@test "XDG exception registry has unique paths and known preservation policies" {
	run awk -F '\t' '
        NR == 1 { next }
        {
            if (NF != 4 || $1 == "" || $1 ~ /[[:space:]]/ || paths[$1]++ ||
                $2 !~ /^[a-z][a-z-]*$/ || $4 == "") invalid = 1
            if ($3 != "keep" && $3 != "preserve") invalid = 1
        }
        END { if (NR < 2) invalid = 1; exit invalid }
    ' "${MANTLE_ROOT}/config/xdg-exceptions.tsv"
	assert_success
}

@test "shipped example config validates without executing it" {
	run env -i HOME="${BATS_TEST_TMPDIR}" PATH="${PATH}" MANTLE_ROOT="${MANTLE_ROOT}" \
		"${MANTLE_ROOT}/bin/mantle" config validate "${MANTLE_ROOT}/config/example.conf"
	assert_success
	assert_output_contains "status: loaded"
}
