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
_ok()     { printf "%s✓ %s%s\n" "${COLOR_GREEN}" "$*" "${COLOR_RESET}"; }
_fail()   { printf "%s✗ %s%s\n" "${COLOR_RED}" "$*" "${COLOR_RESET}"; }
_warn()   { printf "%s! %s%s\n" "${COLOR_YELLOW}" "$*" "${COLOR_RESET}"; }

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

	if (( major > REQUIRED_BATS_MAJOR )); then return 0; fi
	if (( major == REQUIRED_BATS_MAJOR && minor >= REQUIRED_BATS_MINOR )); then return 0; fi

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
# Static validation
# ---------------------------------------------------------------------------

_run_static() {
	local static_status=0
	_header "Static Validation"

	# Bash syntax
	printf "Checking Bash syntax...\n"
	while IFS= read -r -d '' f; do
		if ! /bin/bash -n "${f}" 2>/tmp/mantle_syntax_err; then
			_fail "Bash syntax error: ${f}"
			cat /tmp/mantle_syntax_err >&2
			static_status=1
		fi
	done < <(find "${MANTLE_ROOT}" \
		\( -path "${MANTLE_ROOT}/.git" -prune \) -o \
		\( -path "${MANTLE_ROOT}/tests/bats" -prune \) -o \
		\( -path "${MANTLE_ROOT}/vendor" -prune \) -o \
		\( -name "*.sh" -print0 \))
	[[ "${static_status}" -eq 0 ]] && _ok "Bash syntax"

	# Zsh syntax (optional)
	if command -v zsh >/dev/null 2>&1; then
		printf "Checking Zsh syntax...\n"
		local zsh_status=0
		while IFS= read -r -d '' f; do
			if ! zsh -n "${f}" 2>/dev/null; then
				_fail "Zsh syntax error: ${f}"
				zsh_status=1
			fi
		done < <(find "${MANTLE_ROOT}" \
			\( -path "${MANTLE_ROOT}/.git" -prune \) -o \
			\( -path "${MANTLE_ROOT}/tests/bats" -prune \) -o \
			\( -name "*.sh" -print0 \))
		[[ "${zsh_status}" -eq 0 ]] && _ok "Zsh syntax" || static_status=1
	else
		_warn "Zsh not available; skipping Zsh syntax check"
	fi

	# Fish syntax (optional)
	if command -v fish >/dev/null 2>&1; then
		printf "Checking Fish syntax...\n"
		local fish_status=0
		while IFS= read -r -d '' f; do
			if ! fish -n "${f}" 2>/dev/null; then
				_fail "Fish syntax error: ${f}"
				fish_status=1
			fi
		done < <(find "${MANTLE_ROOT}" \
			\( -path "${MANTLE_ROOT}/.git" -prune \) -o \
			\( -name "*.fish" -print0 \))
		[[ "${fish_status}" -eq 0 ]] && _ok "Fish syntax" || static_status=1
	else
		_warn "Fish not available; skipping Fish syntax check"
	fi

	# ShellCheck (optional but recommended)
	if command -v shellcheck >/dev/null 2>&1; then
		printf "Checking ShellCheck...\n"
		local sc_status=0
		local -a sh_files=()
		# Collect .sh files, skipping Zsh scripts (not supported by shellcheck).
		while IFS= read -r -d '' f; do
			local first_line
			first_line="$(head -1 "${f}" 2>/dev/null)"
			case "${first_line}" in
				*zsh*) ;;
				*) sh_files+=("${f}") ;;
			esac
		done < <(find "${MANTLE_ROOT}" \
			\( -path "${MANTLE_ROOT}/.git" -prune \) -o \
			\( -path "${MANTLE_ROOT}/tests/bats" -prune \) -o \
			\( -path "${MANTLE_ROOT}/vendor" -prune \) -o \
			\( -name "*.sh" -print0 \))

		if (( ${#sh_files[@]} > 0 )); then
			if shellcheck --severity=style \
				--exclude=SC1090,SC1091,SC2034,SC2317 \
				"${sh_files[@]}" 2>&1; then
				_ok "ShellCheck"
			else
				_fail "ShellCheck found issues"
				sc_status=1
				static_status=1
			fi
		fi
		# Suppress unused variable warning — sc_status used above.
		: "${sc_status}"
	else
		_warn "shellcheck not available; skipping ShellCheck"
	fi

	# shfmt (optional)
	if command -v shfmt >/dev/null 2>&1; then
		printf "Running shfmt...\n"
		if shfmt -d "${MANTLE_ROOT}" 2>/dev/null; then
			_ok "shfmt formatting"
		else
			_fail "shfmt found formatting issues (run: shfmt -w .)"
			static_status=1
		fi
	else
		_warn "shfmt not available; skipping formatting check"
	fi

	return "${static_status}"
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
		all | unit | integration | contract | static) ;;
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
			printf "Usage: %s [all|unit|integration|contract|static|<file.bats>]\n" "$0" >&2
			return 1
			;;
	esac

	# Static validation doesn't need bats
	if [[ "${mode}" == "static" ]]; then
		_run_static
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
