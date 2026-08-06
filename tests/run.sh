#!/usr/bin/env bash
# shellcheck shell=bash
#
# Mantle test runner.
#
# Usage:
#   ./tests/run.sh              Run the complete test suite.
#   ./tests/run.sh unit         Run unit tests only.
#   ./tests/run.sh integration  Run integration tests only.
#   ./tests/run.sh contract     Run contract tests only.
#   ./tests/run.sh static       Run static validation only.
#   ./tests/run.sh format       Rewrite maintained shell sources with shfmt.
#   ./tests/run.sh <file.bats>  Run a specific Bats test file.

set -o errexit
set -o nounset
set -o pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MANTLE_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MANTLE_ROOT="$(cd "${MANTLE_TEST_DIR}/.." && pwd -P)"
export MANTLE_TEST_DIR MANTLE_ROOT

REQUIRED_BATS_MAJOR=1
REQUIRED_BATS_MINOR=5
BATS_CMD=""

RUNNER_STATUS=0

# ---------------------------------------------------------------------------
# Colors (disabled when not a terminal)
# ---------------------------------------------------------------------------

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

_header() { printf "%s%s=== %s ===%s\n" "${COLOR_BOLD}" "${COLOR_CYAN}" "$*" "${COLOR_RESET}"; }
_ok() { printf "%s✓ %s%s\n" "${COLOR_GREEN}" "$*" "${COLOR_RESET}"; }
_fail() { printf "%s✗ %s%s\n" "${COLOR_RED}" "$*" "${COLOR_RESET}"; }
_warn() { printf "%s! %s%s\n" "${COLOR_YELLOW}" "$*" "${COLOR_RESET}"; }

# ---------------------------------------------------------------------------
# Bats discovery
# ---------------------------------------------------------------------------

_find_bats() {
	local candidate
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
	local version_string major minor
	version_string="$("${BATS_CMD}" --version 2>&1)" || return 1
	major="$(printf "%s\n" "${version_string}" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | cut -d. -f1)"
	minor="$(printf "%s\n" "${version_string}" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | cut -d. -f2)"

	if ((major > REQUIRED_BATS_MAJOR)); then return 0; fi
	if ((major == REQUIRED_BATS_MAJOR && minor >= REQUIRED_BATS_MINOR)); then return 0; fi

	printf "%sBats %d.%d+ is required (found %s)%s\n" \
		"${COLOR_RED}" "${REQUIRED_BATS_MAJOR}" "${REQUIRED_BATS_MINOR}" \
		"${version_string}" "${COLOR_RESET}" >&2
	return 1
}

_require_bats() {
	if ! _find_bats; then
		printf "%sError: bats is not installed or not on PATH.%s\n" "${COLOR_RED}" "${COLOR_RESET}" >&2
		printf "\nInstall Bats %d.%d+ using one of:\n" "${REQUIRED_BATS_MAJOR}" "${REQUIRED_BATS_MINOR}" >&2
		printf "  npm install -g bats\n" >&2
		printf "  brew install bats-core\n" >&2
		printf "  https://github.com/bats-core/bats-core#installation\n" >&2
		return 1
	fi
	_check_bats_version
}

# ---------------------------------------------------------------------------
# Maintained shell source inventory
# ---------------------------------------------------------------------------

_find_bash_files() {
	printf '%s\0' \
		"${MANTLE_ROOT}/install.sh" \
		"${MANTLE_ROOT}/tests/run.sh"
	find \
		"${MANTLE_ROOT}/init" \
		"${MANTLE_ROOT}/lib" \
		"${MANTLE_ROOT}/libexec" \
		"${MANTLE_ROOT}/modules" \
		"${MANTLE_ROOT}/platforms" \
		"${MANTLE_ROOT}/tests" \
		-type f \
		\( -name "*.sh" -o -name "*.bash" \) \
		-print0
	find "${MANTLE_ROOT}/runtime/shells/bash" -type f -name "*.sh" -print0
	find "${MANTLE_ROOT}/bin" -maxdepth 1 -type f -print0 | while IFS= read -r -d '' file_path; do
		if head -n 1 "${file_path}" 2>/dev/null | grep -Fqx '#!/usr/bin/env bash'; then
			printf '%s\0' "${file_path}"
		fi
	done
}

_find_posix_files() {
	printf '%s\0' \
		"${MANTLE_ROOT}/runtime/shared/runtime.sh" \
		"${MANTLE_ROOT}/runtime/shells/posix/runtime.sh"
}

_find_bats_files() {
	find "${MANTLE_ROOT}/tests" -type f -name "*.bats" -print0
}

_find_zsh_files() {
	printf '%s\0' "${MANTLE_ROOT}/runtime/shells/zsh/runtime.sh"
}

_find_fish_files() {
	find "${MANTLE_ROOT}/runtime/shells/fish" -type f -name "*.fish" -print0
}

_read_null_array() {
	local callback="${1:?}"
	local file_path=""

	while IFS= read -r -d '' file_path; do
		printf '%s\0' "${file_path}"
	done < <("${callback}")
}

_load_file_array() {
	local callback="${1:?}"
	local destination_name="${2:?}"
	local file_path=""

	eval "${destination_name}=()"
	while IFS= read -r -d '' file_path; do
		eval "${destination_name}+=(\"\${file_path}\")"
	done < <(_read_null_array "${callback}")
}

# ---------------------------------------------------------------------------
# Static validation
# ---------------------------------------------------------------------------

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
	local static_status=0
	local file_path=""
	local syntax_status=0
	local shfmt_status=0
	local -a bash_files=()
	local -a posix_files=()
	local -a bats_files=()
	local -a zsh_files=()
	local -a fish_files=()
	local -a shellcheck_files=()
	_header "Static Validation"

	_load_file_array _find_bash_files bash_files
	_load_file_array _find_posix_files posix_files
	_load_file_array _find_bats_files bats_files
	_load_file_array _find_zsh_files zsh_files
	_load_file_array _find_fish_files fish_files

	# Bash syntax
	printf "Checking Bash syntax...\n"
	for file_path in "${bash_files[@]}"; do
		if ! /bin/bash -n "${file_path}" 2>/tmp/mantle_syntax_err; then
			_fail "Bash syntax error: ${file_path}"
			cat /tmp/mantle_syntax_err >&2
			syntax_status=1
			static_status=1
		fi
	done
	[[ "${syntax_status}" -eq 0 ]] && _ok "Bash syntax"

	# POSIX syntax
	printf "Checking POSIX shell syntax...\n"
	syntax_status=0
	for file_path in "${posix_files[@]}"; do
		if ! /bin/sh -n "${file_path}" 2>/tmp/mantle_syntax_err; then
			_fail "POSIX syntax error: ${file_path}"
			cat /tmp/mantle_syntax_err >&2
			syntax_status=1
			static_status=1
		fi
	done
	[[ "${syntax_status}" -eq 0 ]] && _ok "POSIX shell syntax"

	# Zsh syntax (optional)
	if command -v zsh >/dev/null 2>&1; then
		printf "Checking Zsh syntax...\n"
		syntax_status=0
		for file_path in "${zsh_files[@]}"; do
			if ! zsh -n "${file_path}" 2>/tmp/mantle_syntax_err; then
				_fail "Zsh syntax error: ${file_path}"
				cat /tmp/mantle_syntax_err >&2
				syntax_status=1
				static_status=1
			fi
		done
		[[ "${syntax_status}" -eq 0 ]] && _ok "Zsh syntax"
	else
		_warn "Zsh not available; skipping Zsh syntax check"
	fi

	# Fish syntax (optional)
	if command -v fish >/dev/null 2>&1; then
		printf "Checking Fish syntax...\n"
		syntax_status=0
		for file_path in "${fish_files[@]}"; do
			if ! fish -n "${file_path}" 2>/tmp/mantle_syntax_err; then
				_fail "Fish syntax error: ${file_path}"
				cat /tmp/mantle_syntax_err >&2
				syntax_status=1
				static_status=1
			fi
		done
		[[ "${syntax_status}" -eq 0 ]] && _ok "Fish syntax"
	else
		_warn "Fish not available; skipping Fish syntax check"
	fi

	# ShellCheck (optional but recommended)
	if command -v shellcheck >/dev/null 2>&1; then
		printf "Checking ShellCheck...\n"
		shellcheck_files=()
		for file_path in "${bash_files[@]}" "${posix_files[@]}"; do
			case "${file_path}" in
			*.sh) shellcheck_files+=("${file_path}") ;;
			esac
		done
		if shellcheck --severity=style \
			--exclude=SC1090,SC1091,SC2034,SC2317 \
			"${shellcheck_files[@]}" 2>&1; then
			_ok "ShellCheck"
		else
			_fail "ShellCheck found issues"
			static_status=1
		fi
	else
		_warn "shellcheck not available; skipping ShellCheck"
	fi

	# shdoc (optional)
	if command -v shdoc >/dev/null 2>&1; then
		printf "Checking shdoc...\n"
		if shdoc "${MANTLE_ROOT}/install.sh" >/dev/null 2>&1; then
			_ok "shdoc"
		else
			_fail "shdoc could not parse install.sh"
			static_status=1
		fi
	else
		_warn "shdoc not available; skipping shdoc validation"
	fi

	# shfmt (optional)
	if command -v shfmt >/dev/null 2>&1; then
		printf "Checking shfmt formatting...\n"
		if _run_shfmt_group d bash "${bash_files[@]}" &&
			_run_shfmt_group d posix "${posix_files[@]}" &&
			_run_shfmt_group d bats "${bats_files[@]}"; then
			_ok "shfmt formatting"
		else
			_fail "shfmt found formatting issues (run: ./tests/run.sh format)"
			static_status=1
		fi
		_warn "shfmt skips .shellrc and runtime/shells/zsh/runtime.sh because shfmt does not support Mantle's Bash/Zsh hybrid entrypoint or native Zsh syntax"
	else
		_warn "shfmt not available; skipping formatting check"
	fi

	return "${static_status}"
}

_run_format() {
	local -a bash_files=()
	local -a posix_files=()
	local -a bats_files=()

	if ! command -v shfmt >/dev/null 2>&1; then
		printf "%sshfmt is required for format mode.%s\n" "${COLOR_RED}" "${COLOR_RESET}" >&2
		return 1
	fi

	_load_file_array _find_bash_files bash_files
	_load_file_array _find_posix_files posix_files
	_load_file_array _find_bats_files bats_files

	_header "Formatting Shell Sources"
	_run_shfmt_group w bash "${bash_files[@]}"
	_run_shfmt_group w posix "${posix_files[@]}"
	_run_shfmt_group w bats "${bats_files[@]}"
	_warn "shfmt skips .shellrc and runtime/shells/zsh/runtime.sh because shfmt does not support Mantle's Bash/Zsh hybrid entrypoint or native Zsh syntax"
	_ok "Formatted maintained shell sources"
}

# ---------------------------------------------------------------------------
# Bats test execution
# ---------------------------------------------------------------------------

_run_bats() {
	local suite_name="${1:?}"
	local bats_args=("${@:2}")

	_header "Bats: ${suite_name}"
	"${BATS_CMD}" --no-tempdir-cleanup "${bats_args[@]}"
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

main() {
	local mode="${1:-all}"

	case "${mode}" in
	all | unit | integration | contract | static | format | bin) ;;
	*.bats)
		_require_bats
		_run_bats "custom" "${mode}"
		return $?
		;;
	*)
		if [[ -f "${mode}" ]]; then
			_require_bats
			_run_bats "custom" "${mode}"
			return $?
		fi
		printf "Usage: %s [all|unit|integration|contract|bin|static|format|<file.bats>]\n" "$0" >&2
		return 1
		;;
	esac

	# Static validation doesn't need bats
	if [[ "${mode}" == "static" ]]; then
		_run_static
		return $?
	fi

	if [[ "${mode}" == "format" ]]; then
		_run_format
		return $?
	fi

	_require_bats

	if [[ "${mode}" == "all" || "${mode}" == "unit" ]]; then
		_run_bats "unit" "${MANTLE_TEST_DIR}/unit" --recursive || RUNNER_STATUS=$?
	fi

	if [[ "${mode}" == "all" || "${mode}" == "integration" ]]; then
		_run_bats "integration" "${MANTLE_TEST_DIR}/integration" --recursive || RUNNER_STATUS=$?
	fi

	if [[ "${mode}" == "all" || "${mode}" == "contract" ]]; then
		_run_bats "contract" "${MANTLE_TEST_DIR}/contract" --recursive || RUNNER_STATUS=$?
	fi

	if [[ "${mode}" == "all" || "${mode}" == "bin" ]]; then
		_run_bats "bin" "${MANTLE_TEST_DIR}/bin" --recursive || RUNNER_STATUS=$?
	fi

	if [[ "${mode}" == "all" ]]; then
		_run_static || RUNNER_STATUS=$?
	fi

	if [[ "${RUNNER_STATUS}" -eq 0 ]]; then
		_ok "All validations passed."
	else
		_fail "One or more validations failed."
	fi

	return "${RUNNER_STATUS}"
}

main "$@"
