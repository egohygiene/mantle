#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Offline evidence for verified CI-tool acquisition and fail-before-install behavior.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	setup_stub_dir

	CI_FIXTURE_ROOT="${TEST_HOME}/fixture-repository"
	CI_FIXTURE_PAYLOADS="${TEST_HOME}/payloads"
	CI_FIXTURE_PREFIX="${TEST_HOME}/prefix"
	CI_FIXTURE_LOCK="${TEST_HOME}/tools.tsv"
	export CI_FIXTURE_PAYLOADS
	export CI_FIXTURE_INSTALL_MARKER="${TEST_HOME}/installer-ran"
	export CI_FIXTURE_EXECUTION_MARKER="${TEST_HOME}/payload-ran"
	export CI_FIXTURE_OS="Linux" CI_FIXTURE_ARCH="x86_64"
	export CI_FIXTURE_DOWNLOAD_FAIL="0"
	mkdir -p "${CI_FIXTURE_ROOT}/scripts/ci" "${CI_FIXTURE_PAYLOADS}" "${CI_FIXTURE_PREFIX}"
	cp "${MANTLE_ROOT}/scripts/ci/setup-tools.sh" "${CI_FIXTURE_ROOT}/scripts/ci/"
	cp -R "${MANTLE_ROOT}/lib" "${CI_FIXTURE_ROOT}/"
	printf "preserved\n" >"${CI_FIXTURE_PREFIX}/sentinel"
	printf "tool\tversion\tplatform\turl\tsha256\n" >"${CI_FIXTURE_LOCK}"

	cat >"${STUB_DIR}/uname" <<'STUB'
#!/bin/sh
case "$1" in
-s) printf "%s\n" "${CI_FIXTURE_OS}" ;;
-m) printf "%s\n" "${CI_FIXTURE_ARCH}" ;;
*) exit 64 ;;
esac
STUB
	cat >"${STUB_DIR}/curl" <<'STUB'
#!/bin/sh
printf "download\n" >>"${STUB_DIR}/curl.calls"
if [ "${CI_FIXTURE_DOWNLOAD_FAIL}" = "1" ]; then
	printf "fixture artifact unavailable\n" >&2
	exit 22
fi
destination=""
url=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	--output | -o) destination="$2"; shift 2 ;;
	https://*) url="$1"; shift ;;
	*) shift ;;
	esac
done
case "${url}" in
https://fixtures.invalid/*) cp "${CI_FIXTURE_PAYLOADS}/${url##*/}" "${destination}" ;;
*) printf "unexpected fixture URL: %s\n" "${url}" >&2; exit 64 ;;
esac
STUB
	chmod 0755 "${STUB_DIR}/uname" "${STUB_DIR}/curl"
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

# @description Calculate fixture digests using a host-supported SHA-256 utility.
# @arg $1 string Fixture artifact path.
# @stdout SHA-256 digest.
ci_fixture_digest() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

# @description Add one explicit trusted fixture pin to the data lock.
# @arg $1 string Tool name.
# @arg $2 string Tool version or full commit.
# @arg $3 string Platform selector.
# @arg $4 string Payload basename.
# @arg $5 string Optional expected digest, defaults to the payload's actual digest.
ci_fixture_pin() {
	local digest="${5:-}"
	if [[ -z "${digest}" ]]; then
		digest="$(ci_fixture_digest "${CI_FIXTURE_PAYLOADS}/$4")"
	fi
	printf "%s\t%s\t%s\thttps://fixtures.invalid/%s\t%s\n" \
		"$1" "$2" "$3" "$4" "${digest}" >>"${CI_FIXTURE_LOCK}"
}

# @description Create an executable-shaped payload that records any execution.
# @arg $1 string Tool name.
ci_fixture_executable() {
	cat >"${CI_FIXTURE_PAYLOADS}/$1" <<'PAYLOAD'
#!/bin/sh
printf "executed\n" >>"${CI_FIXTURE_EXECUTION_MARKER}"
printf "fixture tool\n"
PAYLOAD
}

# @description Create a versioned Bats archive whose installer records execution.
ci_fixture_bats_archive() {
	local archive_root="${TEST_HOME}/archive"
	mkdir -p "${archive_root}/bats-core-1.11.0"
	cat >"${archive_root}/bats-core-1.11.0/install.sh" <<'INSTALLER'
#!/bin/bash
set -o errexit
printf "installed\n" >>"${CI_FIXTURE_INSTALL_MARKER}"
mkdir -p "$1/bin"
printf '#!/bin/sh\nprintf "Bats 1.11.0\\n"\n' >"$1/bin/bats"
chmod 0755 "$1/bin/bats"
INSTALLER
	tar -czf "${CI_FIXTURE_PAYLOADS}/bats.tar.gz" -C "${archive_root}" bats-core-1.11.0
	ci_fixture_pin bats 1.11.0 any bats.tar.gz
}

# @description Invoke the fixture copy through stock Bash and its public interface.
# @arg $@ string Tool names or additional setup arguments.
ci_fixture_setup() {
	run /bin/bash "${CI_FIXTURE_ROOT}/scripts/ci/setup-tools.sh" \
		--prefix "${CI_FIXTURE_PREFIX}" --lockfile "${CI_FIXTURE_LOCK}" "$@"
}

# @description Confirm failed acquisition neither executed payloads nor installed files.
ci_fixture_assert_no_install() {
	[[ ! -e "${CI_FIXTURE_INSTALL_MARKER}" ]]
	[[ ! -e "${CI_FIXTURE_EXECUTION_MARKER}" ]]
	[[ "$(cat "${CI_FIXTURE_PREFIX}/sentinel")" == "preserved" ]]
	[[ "$(find "${CI_FIXTURE_PREFIX}" -type f | wc -l | tr -d ' ')" -eq 1 ]]
}

@test "CI setup verifies and installs shfmt without executing the downloaded payload" {
	ci_fixture_executable shfmt
	ci_fixture_pin shfmt 3.8.0 linux-amd64 shfmt
	ci_fixture_setup shfmt
	assert_success
	[[ -x "${CI_FIXTURE_PREFIX}/bin/shfmt" ]]
	[[ ! -e "${CI_FIXTURE_EXECUTION_MARKER}" ]]
	cmp "${CI_FIXTURE_PAYLOADS}/shfmt" "${CI_FIXTURE_PREFIX}/bin/shfmt"
}

@test "CI setup installs shdoc from an explicit full-commit pin" {
	ci_fixture_executable shdoc
	ci_fixture_pin shdoc 52917b2f3471fe77c745ede115494d2d5c9168d1 linux-amd64 shdoc
	ci_fixture_setup shdoc
	assert_success
	[[ -x "${CI_FIXTURE_PREFIX}/bin/shdoc" ]]
	[[ ! -e "${CI_FIXTURE_EXECUTION_MARKER}" ]]
}

@test "CI setup verifies the Bats source archive before invoking its installer" {
	ci_fixture_bats_archive
	ci_fixture_setup bats
	assert_success
	[[ "$(cat "${CI_FIXTURE_INSTALL_MARKER}")" == "installed" ]]
	run "${CI_FIXTURE_PREFIX}/bin/bats" --version
	assert_success
	assert_output_contains "Bats 1.11.0"
}

@test "CI setup uses the same portable Bats pin on Darwin ARM64" {
	ci_fixture_bats_archive
	export CI_FIXTURE_OS="Darwin" CI_FIXTURE_ARCH="arm64"
	ci_fixture_setup bats
	assert_success
	[[ -x "${CI_FIXTURE_PREFIX}/bin/bats" ]]
}

@test "CI setup rejects a wrong digest before extracting or running Bats" {
	ci_fixture_bats_archive
	local valid_digest=""
	valid_digest="$(ci_fixture_digest "${CI_FIXTURE_PAYLOADS}/bats.tar.gz")"
	sed "s/${valid_digest}/0000000000000000000000000000000000000000000000000000000000000000/" \
		"${CI_FIXTURE_LOCK}" >"${TEST_HOME}/wrong.tsv"
	cp "${TEST_HOME}/wrong.tsv" "${CI_FIXTURE_LOCK}"
	create_recording_stub tar 99
	ci_fixture_setup bats
	assert_failure
	assert_output_contains "checksum"
	[[ ! -e "${STUB_DIR}/tar.calls" ]]
	ci_fixture_assert_no_install
}

@test "CI setup fails unavailable downloads before installation with a tool diagnostic" {
	ci_fixture_bats_archive
	export CI_FIXTURE_DOWNLOAD_FAIL="1"
	ci_fixture_setup bats
	assert_failure
	assert_output_contains "bats"
	ci_fixture_assert_no_install
}

@test "CI setup rejects malformed digest and duplicate pins before any download" {
	ci_fixture_executable shfmt
	ci_fixture_pin shfmt 3.8.0 linux-amd64 shfmt invalid-digest
	ci_fixture_setup shfmt
	assert_failure
	[[ ! -e "${STUB_DIR}/curl.calls" ]]
	ci_fixture_assert_no_install

	printf "tool\tversion\tplatform\turl\tsha256\n" >"${CI_FIXTURE_LOCK}"
	ci_fixture_pin shfmt 3.8.0 linux-amd64 shfmt
	ci_fixture_pin shfmt 3.8.0 linux-amd64 shfmt
	ci_fixture_setup shfmt
	assert_failure
	[[ ! -e "${STUB_DIR}/curl.calls" ]]
	ci_fixture_assert_no_install
}

@test "CI setup rejects unsupported platform or unknown tool before any download" {
	ci_fixture_executable shfmt
	ci_fixture_pin shfmt 3.8.0 linux-amd64 shfmt
	export CI_FIXTURE_OS="Plan9"
	ci_fixture_setup shfmt
	assert_failure
	[[ ! -e "${STUB_DIR}/curl.calls" ]]
	ci_fixture_assert_no_install

	export CI_FIXTURE_OS="Linux"
	ci_fixture_setup unknown-tool
	assert_failure
	[[ ! -e "${STUB_DIR}/curl.calls" ]]
	ci_fixture_assert_no_install
}

@test "CI setup rejects a non-commit shdoc pin before any download" {
	ci_fixture_executable shdoc
	ci_fixture_pin shdoc master linux-amd64 shdoc
	ci_fixture_setup shdoc
	assert_failure
	[[ ! -e "${STUB_DIR}/curl.calls" ]]
	ci_fixture_assert_no_install
}

@test "CI setup verifies artifacts with shasum when sha256sum is unavailable" {
	local portable_path="${TEST_HOME}/portable-path"
	local utility=""
	export CI_FIXTURE_REAL_SHASUM="$(command -v shasum)"
	[[ -n "${CI_FIXTURE_REAL_SHASUM}" ]] || skip "shasum is not available on this system"
	ci_fixture_executable shfmt
	ci_fixture_pin shfmt 3.8.0 linux-amd64 shfmt
	mkdir -p "${portable_path}"
	for utility in awk cp dirname install mkdir mktemp mv rm tr; do
		ln -s "$(command -v "${utility}")" "${portable_path}/${utility}"
	done
	ln -s "${STUB_DIR}/curl" "${portable_path}/curl"
	ln -s "${STUB_DIR}/uname" "${portable_path}/uname"
	cat >"${portable_path}/shasum" <<'STUB'
#!/bin/sh
printf "verified\n" >>"${STUB_DIR}/shasum.calls"
exec "${CI_FIXTURE_REAL_SHASUM}" "$@"
STUB
	chmod 0755 "${portable_path}/shasum"
	run env PATH="${portable_path}" /bin/bash "${CI_FIXTURE_ROOT}/scripts/ci/setup-tools.sh" \
		--prefix "${CI_FIXTURE_PREFIX}" --lockfile "${CI_FIXTURE_LOCK}" shfmt
	assert_success
	[[ "$(cat "${STUB_DIR}/shasum.calls")" == "verified" ]]
	[[ -x "${CI_FIXTURE_PREFIX}/bin/shfmt" ]]
	[[ ! -e "${CI_FIXTURE_EXECUTION_MARKER}" ]]
}

@test "CI setup rejects a malformed second tool pin before acquiring the first" {
	ci_fixture_executable shfmt
	ci_fixture_executable shdoc
	ci_fixture_pin shfmt 3.8.0 linux-amd64 shfmt
	ci_fixture_pin shdoc master linux-amd64 shdoc
	ci_fixture_setup shfmt shdoc
	assert_failure
	assert_output_contains "pin"
	[[ ! -e "${STUB_DIR}/curl.calls" ]]
	ci_fixture_assert_no_install
}
