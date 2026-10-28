#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Behavioral tests for bin/sysinfo with synthetic host and network data.

setup() {
	load 'helpers/environment'
	load 'helpers/assertions'
	load 'helpers/stubs'
	bin_test_setup
	SYSINFO_TOOLS="${BIN_STUB_DIR}/sysinfo-tools"
	mkdir -p "${SYSINFO_TOOLS}"
	# Only formatting utilities and controlled diagnostics reach the CLI. Keep
	# the Bats process on its usual PATH so its own utilities are unaffected.
	ln -s /bin/bash "${SYSINFO_TOOLS}/bash"
	local tool
	for tool in cat tr awk sort; do
		ln -s "$(command -v "${tool}")" "${SYSINFO_TOOLS}/${tool}"
	done
	_sysinfo_stub uname 0 Linux
	_sysinfo_stub date 0 '2026-01-01T00:00:00Z'
	_sysinfo_stub df 0 'fixture-disk 100G 25G 75G 25% /'
	_sysinfo_stub ip 0 'fixture0 UP 192.0.2.10/24'
	_sysinfo_stub ss 0 'tcp LISTEN 0 128 192.0.2.10:4242 0.0.0.0:*'
	cat >"${SYSINFO_TOOLS}/hostname" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"${0}.calls"
case "${1:-}" in
    '') printf 'sysinfo-fixture\n' ;;
    -I) exit 1 ;;
    *) exit 64 ;;
esac
STUB
	chmod 0755 "${SYSINFO_TOOLS}/hostname"
}

teardown() {
	bin_test_teardown
}

# @description Create a recording diagnostic stub only in the private CLI PATH.
# @arg $@ string Arguments accepted by the existing recording-stub helper.
_sysinfo_stub() {
	BIN_STUB_DIR="${SYSINFO_TOOLS}" make_recording_stub "$@"
}

# @description Create a failing diagnostic with synthetic stderr and exit status.
# @arg $1 string Diagnostic command name.
# @arg $2 integer Exit status to preserve.
_sysinfo_denied_stub() {
	local name="$1" exit_code="$2"
	{
		cat <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"${0}.calls"
printf '%s: fixture permission denied\n' "${0##*/}" >&2
STUB
		printf 'exit %d\n' "${exit_code}"
	} >"${SYSINFO_TOOLS}/${name}"
	chmod 0755 "${SYSINFO_TOOLS}/${name}"
}

# @description Run the real sysinfo CLI with the private tools and a clean environment.
# @arg $@ string CLI arguments.
_run_sysinfo() {
	run_bin_with_env sysinfo "PATH=${SYSINFO_TOOLS}" -- "$@"
}

# @description Print the recorded arguments for one synthetic diagnostic.
# @arg $1 string Diagnostic command name.
_sysinfo_args() {
	BIN_STUB_DIR="${SYSINFO_TOOLS}" recording_stub_args "$1"
}

# @description Print the invocation count for one synthetic diagnostic.
# @arg $1 string Diagnostic command name.
_sysinfo_calls() {
	BIN_STUB_DIR="${SYSINFO_TOOLS}" recording_stub_calls "$1"
}

@test "sysinfo --help exits 0 and documents incomplete diagnostic status" {
	_run_sysinfo --help
	assert_success
	assert_output_contains "Usage"
	assert_output_contains "status is preserved"
	[[ "$(_sysinfo_calls ip)" == 0 ]]
	[[ "$(_sysinfo_calls ss)" == 0 ]]
}

@test "sysinfo --version exits 0 and prints a version" {
	_run_sysinfo --version
	assert_success
	assert_valid_version
}

@test "sysinfo unknown option exits 64" {
	_run_sysinfo --no-such-flag
	assert_status 64
}

@test "sysinfo defaults omit network and environment without invoking their tools" {
	_run_sysinfo
	assert_success
	assert_output_contains "sysinfo-fixture"
	assert_output_contains "fixture-disk"
	assert_output_not_contains "Network addresses"
	assert_output_not_contains "Listening sockets"
	assert_output_not_contains "Environment variables"
	[[ "$(_sysinfo_calls ip)" == 0 ]]
	[[ "$(_sysinfo_calls ss)" == 0 ]]
	[[ "$(_sysinfo_args hostname)" != *-I* ]]
}

@test "sysinfo --no-color exits 0 without ANSI sequences" {
	_run_sysinfo --no-color
	assert_success
	assert_output_not_contains $'\033['
}

@test "sysinfo --include-network exits 0 with controlled Linux addresses and sockets" {
	_run_sysinfo --include-network
	assert_success
	assert_output_contains 'fixture0 UP 192.0.2.10/24'
	assert_output_contains 'tcp LISTEN 0 128 192.0.2.10:4242'
	assert_output_not_contains "Environment variables"
	[[ "$(_sysinfo_args ip)" == '-brief address' ]]
	[[ "$(_sysinfo_args ss)" == '--listening --numeric --tcp --udp' ]]
}

@test "sysinfo --include-environment redacts sensitive variables and omits network" {
	run_bin_with_env sysinfo "PATH=${SYSINFO_TOOLS}" \
		"MY_PASSWORD=fixture-secret" "PUBLIC_NOTE=fixture-public" -- --include-environment
	assert_success
	assert_output_contains 'MY_PASSWORD=<redacted>'
	assert_output_contains 'PUBLIC_NOTE=fixture-public'
	assert_output_not_contains "fixture-secret"
	assert_output_not_contains "Network addresses"
	[[ "$(_sysinfo_calls ip)" == 0 ]]
	[[ "$(_sysinfo_calls ss)" == 0 ]]
}

@test "sysinfo --all exits 0 and includes both optional sections" {
	_run_sysinfo --all
	assert_success
	assert_output_contains 'fixture0 UP 192.0.2.10/24'
	assert_output_contains 'tcp LISTEN 0 128 192.0.2.10:4242'
	assert_output_contains "Environment variables (redacted)"
}

@test "sysinfo missing network tools reports unavailable sections and exits 0" {
	rm "${SYSINFO_TOOLS}/ip" "${SYSINFO_TOOLS}/ss"
	_run_sysinfo --include-network
	assert_success
	assert_output_contains 'Address information unavailable.'
	assert_output_contains 'Socket information unavailable.'
	[[ "$(_sysinfo_args hostname)" == $'\n-I' ]]
}

@test "sysinfo uses controlled hostname and netstat fallback tools" {
	rm "${SYSINFO_TOOLS}/ip" "${SYSINFO_TOOLS}/ss"
	cat >"${SYSINFO_TOOLS}/hostname" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"${0}.calls"
case "${1:-}" in
    '') printf 'sysinfo-fixture\n' ;;
    -I) printf '192.0.2.20\n' ;;
    *) exit 64 ;;
esac
STUB
	_sysinfo_stub netstat 0 'tcp 0 0 192.0.2.20:4242 0.0.0.0:* LISTEN'
	_run_sysinfo --include-network
	assert_success
	assert_output_contains '192.0.2.20'
	assert_output_contains 'tcp 0 0 192.0.2.20:4242'
	[[ "$(_sysinfo_args hostname)" == $'\n-I\n-I' ]]
	[[ "$(_sysinfo_args netstat)" == '-an' ]]
}

@test "sysinfo formats controlled Darwin ifconfig and netstat output" {
	_sysinfo_stub uname 0 Darwin
	rm "${SYSINFO_TOOLS}/ip" "${SYSINFO_TOOLS}/ss"
	cat >"${SYSINFO_TOOLS}/ifconfig" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"${0}.calls"
cat <<'DATA'
fixture0: flags=0
    inet 192.0.2.30 netmask 0xffffff00
    inet6 2001:db8::30 prefixlen 64
DATA
STUB
	chmod 0755 "${SYSINFO_TOOLS}/ifconfig"
	_sysinfo_stub netstat 0 'tcp4 0 0 192.0.2.30.4242 *.* LISTEN'
	_run_sysinfo --include-network
	assert_success
	assert_output_contains 'fixture0 192.0.2.30'
	assert_output_contains 'fixture0 2001:db8::30'
	assert_output_contains 'tcp4 0 0 192.0.2.30.4242'
	[[ "$(_sysinfo_calls ifconfig)" == 1 ]]
	[[ "$(_sysinfo_args netstat)" == '-an' ]]
	[[ "$(_sysinfo_calls hostname)" == 1 ]]
}

@test "sysinfo preserves a denied address tool status and stops before socket inspection" {
	_sysinfo_denied_stub ip 77
	_run_sysinfo --include-network
	assert_status 77
	assert_output_contains 'ip: fixture permission denied'
	assert_output_not_contains 'Listening sockets'
	[[ "$(_sysinfo_args ip)" == $'-brief address\naddress' ]]
	[[ "$(_sysinfo_calls ss)" == 0 ]]
}

@test "sysinfo preserves a denied socket tool status after the address section" {
	_sysinfo_denied_stub ss 1
	_run_sysinfo --all
	assert_status 1
	assert_output_contains 'fixture0 UP 192.0.2.10/24'
	assert_output_contains 'ss: fixture permission denied'
	assert_output_not_contains 'Environment variables'
	[[ "$(_sysinfo_args ss)" == $'--listening --numeric --tcp --udp\n-lntu' ]]
}

@test "sysinfo preserves denied Darwin address pipeline status" {
	_sysinfo_stub uname 0 Darwin
	rm "${SYSINFO_TOOLS}/ip"
	_sysinfo_denied_stub ifconfig 2
	_run_sysinfo --include-network
	assert_status 2
	assert_output_contains 'ifconfig: fixture permission denied'
	assert_output_not_contains 'Listening sockets'
	[[ "$(_sysinfo_calls ifconfig)" == 1 ]]
	[[ "$(_sysinfo_calls ss)" == 0 ]]
}

@test "sysinfo preserves denied netstat pipeline status" {
	rm "${SYSINFO_TOOLS}/ss"
	_sysinfo_denied_stub netstat 2
	_run_sysinfo --include-network
	assert_status 2
	assert_output_contains 'netstat: fixture permission denied'
	[[ "$(_sysinfo_args netstat)" == '-an' ]]
}
