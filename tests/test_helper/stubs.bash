#!/usr/bin/env bash
# shellcheck shell=bash
#
# Command stub helpers for the Mantle test suite.
#
# Source this file from test files:
#   load '../test_helper/stubs'

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	printf "test_helper/stubs.bash must be sourced by Bats, not executed directly\n" >&2
	exit 1
fi

# ---------------------------------------------------------------------------
# Download backend stubs.
# ---------------------------------------------------------------------------

# stub_curl_success — stub curl to write a fixed body to its -o argument.
# Usage: stub_curl_success "response body"
stub_curl_success() {
	local body="${1:-stub response}"
	local stub_path="${STUB_DIR:?setup_stub_dir must be called first}/curl"
	{
		printf "#!/bin/sh\n"
		printf "# Stub: curl\n"
		printf 'body=%q\n' "${body}"
		printf 'output_file=""\n'
		printf 'while [ "$#" -gt 0 ]; do\n'
		printf '  case "$1" in\n'
		printf '    -o) output_file="$2"; shift 2 ;;\n'
		printf '    --output) output_file="$2"; shift 2 ;;\n'
		printf '    *) shift ;;\n'
		printf '  esac\n'
		printf 'done\n'
		printf 'if [ -n "$output_file" ]; then\n'
		printf '  printf "%%s" "$body" > "$output_file"\n'
		printf 'fi\n'
		printf 'exit 0\n'
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# stub_curl_failure — stub curl to always fail with a given exit code.
stub_curl_failure() {
	local exit_code="${1:-1}"
	local stub_path="${STUB_DIR:?}/curl"
	{
		printf "#!/bin/sh\n"
		printf "exit %d\n" "${exit_code}"
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# stub_wget_success — stub wget to write a fixed body to its -O argument.
stub_wget_success() {
	local body="${1:-stub response}"
	local stub_path="${STUB_DIR:?}/wget"
	{
		printf "#!/bin/sh\n"
		printf 'body=%q\n' "${body}"
		printf 'output_file=""\n'
		printf 'while [ "$#" -gt 0 ]; do\n'
		printf '  case "$1" in\n'
		printf '    -O) output_file="$2"; shift 2 ;;\n'
		printf '    *) shift ;;\n'
		printf '  esac\n'
		printf 'done\n'
		printf 'if [ -n "$output_file" ]; then\n'
		printf '  printf "%%s" "$body" > "$output_file"\n'
		printf 'fi\n'
		printf 'exit 0\n'
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}

# ---------------------------------------------------------------------------
# Package manager stubs.
# ---------------------------------------------------------------------------

# stub_apt_get — stub apt-get to record calls and succeed.
stub_apt_get() {
	create_recording_stub "apt-get" 0
}

# stub_brew — stub brew to record calls and succeed.
stub_brew() {
	create_recording_stub "brew" 0
}

# ---------------------------------------------------------------------------
# Git stubs.
# ---------------------------------------------------------------------------

# stub_git_describe — stub git to return a fixed version string.
stub_git_describe() {
	local version="${1:-v0.0.1-test}"
	local stub_path="${STUB_DIR:?}/git"
	{
		printf "#!/bin/sh\n"
		printf 'case "$*" in\n'
		printf '  *describe*) printf "%%s\\n" %q ;;\n' "${version}"
		printf '  *) exec /usr/bin/git "$@" ;;\n'
		printf 'esac\n'
	} >"${stub_path}"
	chmod 0755 "${stub_path}"
}
