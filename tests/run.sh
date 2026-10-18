#!/usr/bin/env bash
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# shellcheck disable=SC2310 # Functions explicitly return and callers inspect every relevant status.
# shellcheck disable=SC2249 # Closed case statements intentionally treat unmatched values as no-ops.
# Run Mantle's behavioral and static validation suites truthfully.

set -o errexit
set -o nounset
set -o pipefail

MANTLE_RUNNER_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MANTLE_DEFAULT_ROOT="$(cd "${MANTLE_RUNNER_DIRECTORY}/.." && pwd -P)"
MANTLE_ROOT="${MANTLE_TEST_ROOT:-${MANTLE_DEFAULT_ROOT}}"

if [[ "${MANTLE_ROOT}" != /* ]]; then
	printf "[mantle:test:error] MANTLE_TEST_ROOT must be an absolute path\n" >&2
	exit 64
fi

MANTLE_TEST_DIR="${MANTLE_ROOT}/tests"
export MANTLE_ROOT MANTLE_TEST_DIR

readonly REQUIRED_BATS_MAJOR=1
readonly REQUIRED_BATS_MINOR=5

BATS_CMD=""
RUNNER_MODE="all"
RUNNER_STRICT="${MANTLE_VALIDATION_STRICT:-0}"
RUNNER_STATUS=0
RUNNER_PASSED=0
RUNNER_FAILED=0
RUNNER_SKIPPED=0
RUNNER_TEMP_FILES=()
RUNNER_TEMP_FILE=""

BASH_FILES=()
POSIX_FILES=()
BATS_FILES=()
ZSH_FILES=()
FISH_FILES=()

if [[ -t 1 ]]; then
	COLOR_RESET=$'\033[0m'
	COLOR_BOLD=$'\033[1m'
	COLOR_RED=$'\033[31m'
	COLOR_GREEN=$'\033[32m'
	COLOR_YELLOW=$'\033[33m'
	COLOR_CYAN=$'\033[36m'
else
	COLOR_RESET=""
	COLOR_BOLD=""
	COLOR_RED=""
	COLOR_GREEN=""
	COLOR_YELLOW=""
	COLOR_CYAN=""
fi

_header() {
	printf "%s%s=== %s ===%s\n" "${COLOR_BOLD}" "${COLOR_CYAN}" "$*" "${COLOR_RESET}"
}

_ok() {
	printf "%s✓ %s%s\n" "${COLOR_GREEN}" "$*" "${COLOR_RESET}"
}

_fail() {
	printf "%s✗ %s%s\n" "${COLOR_RED}" "$*" "${COLOR_RESET}" >&2
}

_warn() {
	printf "%s! %s%s\n" "${COLOR_YELLOW}" "$*" "${COLOR_RESET}"
}

_record_pass() {
	RUNNER_PASSED=$((RUNNER_PASSED + 1))
	_ok "$*"
}

_record_failure() {
	RUNNER_FAILED=$((RUNNER_FAILED + 1))
	RUNNER_STATUS=1
	_fail "$*"
}

_record_skip() {
	RUNNER_SKIPPED=$((RUNNER_SKIPPED + 1))
	_warn "$*"
}

_cleanup() {
	local temporary_path=""

	for temporary_path in "${RUNNER_TEMP_FILES[@]:-}"; do
		if [[ -n "${temporary_path}" && -f "${temporary_path}" ]]; then
			rm -f "${temporary_path}"
		fi
	done
}

trap _cleanup EXIT HUP INT TERM

_new_temporary_file() {
	RUNNER_TEMP_FILE="$(mktemp "${TMPDIR:-/tmp}/mantle-validation.XXXXXXXXXX")"
	RUNNER_TEMP_FILES+=("${RUNNER_TEMP_FILE}")
}

_print_usage() {
	printf "%s\n" \
		"Usage: ${0} [--strict|--local] [MODE|FILE]" \
		"" \
		"Modes:" \
		"  all          Run unit, integration, contract, bin, and static validation." \
		"  unit         Run unit Bats tests." \
		"  integration  Run integration Bats tests." \
		"  contract     Run contract Bats tests." \
		"  bin          Run every maintained bin CLI Bats test." \
		"  static       Run shell syntax and static-analysis checks." \
		"  format       Rewrite shfmt-maintained shell sources." \
		"" \
		"Local mode explicitly skips unavailable optional static tools." \
		"Strict mode requires Zsh, Fish, ShellCheck, shdoc, and shfmt."
}

_parse_arguments() {
	local positional_count=0

	while (($# > 0)); do
		case "$1" in
		--strict)
			RUNNER_STRICT="1"
			shift
			;;
		--local)
			RUNNER_STRICT="0"
			shift
			;;
		--help | -h)
			_print_usage
			exit 0
			;;
		--)
			shift
			break
			;;
		-*)
			printf "[mantle:test:error] unknown option: %s\n" "$1" >&2
			_print_usage >&2
			return 64
			;;
		*)
			if ((positional_count > 0)); then
				printf "[mantle:test:error] only one mode or test file may be selected\n" >&2
				return 64
			fi
			RUNNER_MODE="$1"
			positional_count=$((positional_count + 1))
			shift
			;;
		esac
	done

	while (($# > 0)); do
		if ((positional_count > 0)); then
			printf "[mantle:test:error] only one mode or test file may be selected\n" >&2
			return 64
		fi
		RUNNER_MODE="$1"
		positional_count=$((positional_count + 1))
		shift
	done

	case "${RUNNER_STRICT}" in
	0 | 1) ;;
	*)
		printf "[mantle:test:error] MANTLE_VALIDATION_STRICT must be 0 or 1\n" >&2
		return 64
		;;
	esac
}

_tool_available() {
	local tool_name="${1:?}"
	local unavailable_tools=",${MANTLE_RUNNER_TEST_UNAVAILABLE_TOOLS:-},"

	case "${unavailable_tools}" in
	*",${tool_name},"*) return 1 ;;
	esac

	command -v "${tool_name}" >/dev/null 2>&1
}

_validate_layout() {
	local relative_path=""
	local layout_valid=1
	local required_directories=(
		"bin"
		"config"
		"init"
		"lib"
		"libexec/mantle/commands"
		"modules"
		"platforms"
		"scripts"
		"runtime/shared"
		"runtime/shells/bash"
		"runtime/shells/fish"
		"runtime/shells/posix"
		"runtime/shells/zsh"
		"tests"
		"tests/bin"
		"tests/contract"
		"tests/integration"
		"tests/unit"
	)
	local required_files=(
		".shellrc"
		"bin/mantle"
		"install.sh"
		"runtime/shared/runtime.sh"
		"runtime/shells/bash/runtime.sh"
		"runtime/shells/fish/runtime.fish"
		"runtime/shells/posix/runtime.sh"
		"runtime/shells/zsh/runtime.sh"
		"tests/run.sh"
	)

	for relative_path in "${required_directories[@]}"; do
		if [[ ! -d "${MANTLE_ROOT}/${relative_path}" ]]; then
			_record_failure "Missing required directory: ${relative_path}/"
			layout_valid=0
		fi
	done

	for relative_path in "${required_files[@]}"; do
		if [[ ! -f "${MANTLE_ROOT}/${relative_path}" ]]; then
			_record_failure "Missing required file: ${relative_path}"
			layout_valid=0
		fi
	done

	if ((layout_valid == 1)); then
		_record_pass "Required repository layout"
		return 0
	fi

	return 1
}

_append_find_results() {
	local destination_name="${1:?}"
	local inventory_label="${2:?}"
	local inventory_file=""
	local file_path=""
	local escaped_path=""
	shift 2

	_new_temporary_file
	inventory_file="${RUNNER_TEMP_FILE}"
	if ! find "$@" -print0 >"${inventory_file}"; then
		_record_failure "Unable to discover ${inventory_label}"
		return 1
	fi

	while IFS= read -r -d '' file_path; do
		printf -v escaped_path "%q" "${file_path}"
		eval "${destination_name}+=( ${escaped_path} )"
	done <"${inventory_file}"
}

_load_source_inventory() {
	local bin_candidates_file=""
	local file_path=""
	local escaped_path=""

	BASH_FILES=("${MANTLE_ROOT}/install.sh")
	POSIX_FILES=(
		"${MANTLE_ROOT}/runtime/shared/runtime.sh"
		"${MANTLE_ROOT}/runtime/shells/posix/runtime.sh"
	)
	BATS_FILES=()
	ZSH_FILES=("${MANTLE_ROOT}/runtime/shells/zsh/runtime.sh")
	FISH_FILES=()

	if ! _append_find_results BASH_FILES "Bash sources" \
		"${MANTLE_ROOT}/init" \
		"${MANTLE_ROOT}/lib" \
		"${MANTLE_ROOT}/libexec" \
		"${MANTLE_ROOT}/modules" \
		"${MANTLE_ROOT}/platforms" \
		"${MANTLE_ROOT}/scripts" \
		"${MANTLE_ROOT}/tests" \
		-type f \( -name "*.sh" -o -name "*.bash" \); then
		return 1
	fi

	if ! _append_find_results BASH_FILES "Bash runtime sources" \
		"${MANTLE_ROOT}/runtime/shells/bash" -type f -name "*.sh"; then
		return 1
	fi

	if ! _append_find_results BATS_FILES "Bats sources" \
		"${MANTLE_ROOT}/tests" -type f -name "*.bats"; then
		return 1
	fi

	if ! _append_find_results FISH_FILES "Fish sources" \
		"${MANTLE_ROOT}/runtime/shells/fish" -type f -name "*.fish"; then
		return 1
	fi

	_new_temporary_file
	bin_candidates_file="${RUNNER_TEMP_FILE}"
	if ! find "${MANTLE_ROOT}/bin" -maxdepth 1 -type f -print0 >"${bin_candidates_file}"; then
		_record_failure "Unable to discover public executables"
		return 1
	fi

	while IFS= read -r -d '' file_path; do
		if head -n 1 "${file_path}" 2>/dev/null | grep -Fqx '#!/usr/bin/env bash'; then
			printf -v escaped_path "%q" "${file_path}"
			eval "BASH_FILES+=( ${escaped_path} )"
		fi
	done <"${bin_candidates_file}"

	if ((${#BASH_FILES[@]} == 0 || ${#POSIX_FILES[@]} == 0 || ${#BATS_FILES[@]} == 0 || ${#ZSH_FILES[@]} == 0 || ${#FISH_FILES[@]} == 0)); then
		_record_failure "One or more maintained source inventories are empty"
		return 1
	fi

	_record_pass "Maintained source discovery"
}

_optional_tool_missing() {
	local tool_name="${1:?}"
	local purpose="${2:?}"

	if [[ "${RUNNER_STRICT}" == "1" ]]; then
		_record_failure "${tool_name} is required in strict mode for ${purpose}"
	else
		_record_skip "${tool_name} unavailable; skipped ${purpose}"
	fi
}

_run_syntax_group() {
	local label="${1:?}"
	local command_name="${2:?}"
	shift 2
	local file_path=""
	local syntax_error_file=""
	local group_valid=1

	_new_temporary_file
	syntax_error_file="${RUNNER_TEMP_FILE}"
	for file_path in "$@"; do
		if ! "${command_name}" -n "${file_path}" 2>"${syntax_error_file}"; then
			_fail "${label} syntax error: ${file_path}"
			cat "${syntax_error_file}" >&2
			group_valid=0
		fi
	done

	if ((group_valid == 1)); then
		_record_pass "${label} syntax"
	else
		_record_failure "${label} syntax"
	fi
}

_run_shfmt_group() {
	local mode="${1:?}"
	local shell_variant="${2:?}"
	shift 2

	if (($# == 0)); then
		return 0
	fi

	shfmt "-ln=${shell_variant}" "-${mode}" "$@"
}

_run_static() {
	local file_path=""
	local shellcheck_files=()

	_header "Static Validation"
	if ! _load_source_inventory; then
		return 0
	fi

	_run_syntax_group "Bash" "/bin/bash" "${BASH_FILES[@]}"
	_run_syntax_group "POSIX shell" "/bin/sh" "${POSIX_FILES[@]}"

	if _tool_available zsh; then
		_run_syntax_group "Zsh" "zsh" "${ZSH_FILES[@]}"
	else
		_optional_tool_missing "zsh" "Zsh syntax validation"
	fi

	if _tool_available fish; then
		_run_syntax_group "Fish" "fish" "${FISH_FILES[@]}"
	else
		_optional_tool_missing "fish" "Fish syntax validation"
	fi

	if _tool_available shellcheck; then
		for file_path in "${BASH_FILES[@]}" "${POSIX_FILES[@]}"; do
			case "${file_path}" in
			*.sh) shellcheck_files+=("${file_path}") ;;
			esac
		done

		# Installer entrypoints source a runtime whose final return belongs to the
		# sourced file; SC2317/SC2329 cannot follow the subsequent execution path.
		if shellcheck --severity=style \
			--exclude=SC1090,SC1091,SC2034,SC2317 \
			"${shellcheck_files[@]}"; then
			_record_pass "ShellCheck"
		else
			_record_failure "ShellCheck"
		fi
	else
		_optional_tool_missing "shellcheck" "ShellCheck analysis"
	fi

	if _tool_available shdoc; then
		if shdoc "${MANTLE_ROOT}/install.sh" >/dev/null; then
			_record_pass "shdoc parsing"
		else
			_record_failure "shdoc parsing"
		fi
	else
		_optional_tool_missing "shdoc" "shdoc parsing"
	fi

	if _tool_available shfmt; then
		if _run_shfmt_group d bash "${BASH_FILES[@]}" &&
			_run_shfmt_group d posix "${POSIX_FILES[@]}" &&
			_run_shfmt_group d bats "${BATS_FILES[@]}"; then
			_record_pass "shfmt formatting"
		else
			_record_failure "shfmt formatting (run: ./tests/run.sh format)"
		fi
		_warn "shfmt intentionally excludes .shellrc and the native Zsh runtime"
	else
		_optional_tool_missing "shfmt" "shfmt formatting"
	fi
}

_run_format() {
	_header "Formatting Shell Sources"
	if ! _load_source_inventory; then
		return 0
	fi

	if ! _tool_available shfmt; then
		_record_failure "shfmt is required for format mode"
		return 0
	fi

	if _run_shfmt_group w bash "${BASH_FILES[@]}" &&
		_run_shfmt_group w posix "${POSIX_FILES[@]}" &&
		_run_shfmt_group w bats "${BATS_FILES[@]}"; then
		_record_pass "Formatted maintained shell sources"
	else
		_record_failure "Unable to format maintained shell sources"
	fi
	_warn "shfmt intentionally excludes .shellrc and the native Zsh runtime"
}

_find_bats() {
	local candidate=""
	local unavailable_tools=",${MANTLE_RUNNER_TEST_UNAVAILABLE_TOOLS:-},"

	case "${unavailable_tools}" in
	*",bats,"*) return 1 ;;
	esac

	for candidate in \
		"${MANTLE_ROOT}/tests/bats/bin/bats" \
		"${MANTLE_ROOT}/vendor/bats-core/bin/bats" \
		"$(command -v bats 2>/dev/null)"; do
		if [[ -x "${candidate}" ]]; then
			BATS_CMD="${candidate}"
			return 0
		fi
	done

	return 1
}

_check_bats_version() {
	local version_string=""
	local version_number=""
	local major=0
	local minor=0

	if ! version_string="$("${BATS_CMD}" --version 2>&1)"; then
		return 1
	fi

	version_number="$(printf "%s\n" "${version_string}" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)"
	if [[ -z "${version_number}" ]]; then
		return 1
	fi

	major="${version_number%%.*}"
	version_number="${version_number#*.}"
	minor="${version_number%%.*}"

	if ((major > REQUIRED_BATS_MAJOR)); then
		return 0
	fi
	if ((major == REQUIRED_BATS_MAJOR && minor >= REQUIRED_BATS_MINOR)); then
		return 0
	fi

	printf "Bats %d.%d+ is required (found %s)\n" \
		"${REQUIRED_BATS_MAJOR}" "${REQUIRED_BATS_MINOR}" "${version_string}" >&2
	return 1
}

_require_bats() {
	if ! _find_bats; then
		_record_failure "Bats ${REQUIRED_BATS_MAJOR}.${REQUIRED_BATS_MINOR}+ is required"
		return 1
	fi

	if ! _check_bats_version; then
		_record_failure "Unable to use the discovered Bats executable"
		return 1
	fi

	return 0
}

_collect_suite_files() {
	local suite_directory="${1:?}"
	local destination_name="${2:?}"
	local suite_name="${3:?}"
	local inventory_file=""
	local file_path=""
	local escaped_path=""
	local count=0

	_new_temporary_file
	inventory_file="${RUNNER_TEMP_FILE}"
	if ! find "${suite_directory}" -type f -name "*.bats" -print0 >"${inventory_file}"; then
		_record_failure "Unable to discover the ${suite_name} suite"
		return 1
	fi

	eval "${destination_name}=()"
	while IFS= read -r -d '' file_path; do
		printf -v escaped_path "%q" "${file_path}"
		eval "${destination_name}+=( ${escaped_path} )"
		count=$((count + 1))
	done <"${inventory_file}"

	if ((count == 0)); then
		_record_failure "The ${suite_name} suite contains no Bats tests"
		return 1
	fi
}

_run_bats_files() {
	local suite_name="${1:?}"
	shift

	_header "Bats: ${suite_name}"
	if "${BATS_CMD}" --no-tempdir-cleanup "$@"; then
		_record_pass "Bats ${suite_name} suite"
	else
		_record_failure "Bats ${suite_name} suite"
	fi
}

_run_bats_directory() {
	local suite_name="${1:?}"
	local suite_directory="${2:?}"
	local suite_files=()

	if _collect_suite_files "${suite_directory}" suite_files "${suite_name}"; then
		_run_bats_files "${suite_name}" "${suite_files[@]}"
	fi
}

_run_bin_suite() {
	# The coverage map guards command coverage, but the directory also contains
	# maintained integration and shared-contract tests that must never be lost.
	_run_bats_directory "bin" "${MANTLE_TEST_DIR}/bin"
}

_run_custom_test() {
	local test_file="${1:?}"

	if [[ ! -f "${test_file}" ]]; then
		_record_failure "Custom test file does not exist: ${test_file}"
		return 0
	fi
	if [[ "${test_file}" != *.bats ]]; then
		_record_failure "Custom test file must use the .bats extension: ${test_file}"
		return 0
	fi

	_run_bats_files "custom" "${test_file}"
}

_print_summary() {
	local validation_mode="local"
	local status_label="passed"

	if [[ "${RUNNER_STRICT}" == "1" ]]; then
		validation_mode="strict"
	fi
	if ((RUNNER_STATUS != 0)); then
		status_label="failed"
	fi

	_header "Validation Summary"
	printf "mode: %s\n" "${validation_mode}"
	printf "passed: %d\n" "${RUNNER_PASSED}"
	printf "failed: %d\n" "${RUNNER_FAILED}"
	printf "skipped: %d\n" "${RUNNER_SKIPPED}"
	printf "status: %s\n" "${status_label}"
}

main() {
	local layout_valid=1
	local bats_available=1

	if ! _parse_arguments "$@"; then
		return 64
	fi

	case "${RUNNER_MODE}" in
	all | unit | integration | contract | bin | static | format) ;;
	*.bats) ;;
	*)
		printf "[mantle:test:error] unknown mode or Bats test file: %s\n" "${RUNNER_MODE}" >&2
		_print_usage >&2
		return 64
		;;
	esac

	if ! _validate_layout; then
		layout_valid=0
	fi

	if ((layout_valid == 1)); then
		case "${RUNNER_MODE}" in
		static)
			_run_static
			;;
		format)
			_run_format
			;;
		all | unit | integration | contract | bin | *.bats)
			if ! _require_bats; then
				bats_available=0
			fi

			if ((bats_available == 1)); then
				case "${RUNNER_MODE}" in
				all)
					_run_bats_directory "unit" "${MANTLE_TEST_DIR}/unit"
					_run_bats_directory "integration" "${MANTLE_TEST_DIR}/integration"
					_run_bats_directory "contract" "${MANTLE_TEST_DIR}/contract"
					_run_bin_suite
					;;
				unit | integration | contract)
					_run_bats_directory "${RUNNER_MODE}" "${MANTLE_TEST_DIR}/${RUNNER_MODE}"
					;;
				bin)
					_run_bin_suite
					;;
				*.bats)
					_run_custom_test "${RUNNER_MODE}"
					;;
				esac
			fi

			if [[ "${RUNNER_MODE}" == "all" ]]; then
				_run_static
			fi
			;;
		esac
	fi

	_print_summary
	return "${RUNNER_STATUS}"
}

main "$@"
