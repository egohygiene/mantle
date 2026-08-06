#!/usr/bin/env bats
# Shared CLI contract tests.
#
# For every command in bin/, verify the minimum shared contract:
#   --help     exits 0 and prints usage text.
#   --version  exits 0 and prints a version number.
#   unknown    exits non-zero with a diagnostic.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	bin_test_setup
}

teardown() {
	bin_test_teardown
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_all_bin_commands() {
	local cmd
	for f in "${MANTLE_ROOT}/bin"/*; do
		[[ -f "${f}" && -x "${f}" ]] && printf "%s\n" "${f##*/}"
	done
}

# ---------------------------------------------------------------------------
# --help contract
# ---------------------------------------------------------------------------

@test "all bin/ commands: --help exits 0 and prints usage text" {
	local failures=0
	while IFS= read -r cmd; do
		run_bin "${cmd}" --help
		if [[ "${status}" -ne 0 ]]; then
			printf "FAIL [--help exits 0]: %s (exit %d)\nOutput: %s\n" \
				"${cmd}" "${status}" "${output}" >&2
			((failures++)) || true
		fi
		if ! printf "%s\n" "${output}" | grep -qiE \
			'usage|options|help|synopsis|description'; then
			printf "FAIL [--help prints usage]: %s\nOutput: %s\n" \
				"${cmd}" "${output}" >&2
			((failures++)) || true
		fi
	done < <(_all_bin_commands)
	[[ "${failures}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# --version contract
# ---------------------------------------------------------------------------

@test "all bin/ commands: --version exits 0 and prints a version number" {
	local failures=0
	while IFS= read -r cmd; do
		run_bin "${cmd}" --version
		if [[ "${status}" -ne 0 ]]; then
			printf "FAIL [--version exits 0]: %s (exit %d)\nOutput: %s\n" \
				"${cmd}" "${status}" "${output}" >&2
			((failures++)) || true
		fi
		if ! printf "%s\n" "${output}" | grep -qE '[0-9]'; then
			printf "FAIL [--version prints version]: %s\nOutput: %s\n" \
				"${cmd}" "${output}" >&2
			((failures++)) || true
		fi
	done < <(_all_bin_commands)
	[[ "${failures}" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Unknown option contract
# ---------------------------------------------------------------------------

@test "all bin/ commands: unrecognized option exits non-zero with a diagnostic" {
	local failures=0
	# A small number of commands may exit 0 for unknown options (e.g., passthrough).
	# Those commands are listed in the exemptions below.
	local -A exempt=(
		# pipes is an interactive screensaver; unrecognized flags are tolerated.
		[pipes]=1
	)
	while IFS= read -r cmd; do
		[[ -n "${exempt[${cmd}]:-}" ]] && continue
		run_bin "${cmd}" --__mantle_unknown_option_xyz__
		if [[ "${status}" -eq 0 ]]; then
			printf "FAIL [unknown option exits non-zero]: %s\nOutput: %s\n" \
				"${cmd}" "${output}" >&2
			((failures++)) || true
		fi
	done < <(_all_bin_commands)
	[[ "${failures}" -eq 0 ]]
}
