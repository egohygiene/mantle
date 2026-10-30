#!/usr/bin/env bats
# Integration tests for the deterministic Mantle source-distribution package.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	RELEASE_SCRIPT="${MANTLE_ROOT}/scripts/package-release.py"
	RELEASE_VERIFY_SCRIPT="${MANTLE_ROOT}/scripts/verify-release.sh"
	RELEASE_VERSION="0.1.2"
}

teardown() {
	teardown_isolated_home
}

@test "package-release builds deterministic source archives with an embedded release version" {
	local first_output="${TEST_HOME}/first"
	local second_output="${TEST_HOME}/second"
	local first_archive="${first_output}/mantle-${RELEASE_VERSION}.tar.gz"
	local second_archive="${second_output}/mantle-${RELEASE_VERSION}.tar.gz"
	local first_digest=""
	local second_digest=""

	run python3 "${RELEASE_SCRIPT}" \
		--include-worktree \
		--source-dir "${MANTLE_ROOT}" \
		--version "${RELEASE_VERSION}" \
		--output-dir "${first_output}"
	assert_success
	assert_file_exists "${first_archive}"

	run python3 "${RELEASE_SCRIPT}" \
		--include-worktree \
		--source-dir "${MANTLE_ROOT}" \
		--version "${RELEASE_VERSION}" \
		--output-dir "${second_output}"
	assert_success
	assert_file_exists "${second_archive}"

	first_digest="$(sha256sum "${first_archive}" | awk '{print $1}')"
	second_digest="$(sha256sum "${second_archive}" | awk '{print $1}')"
	[[ "${first_digest}" == "${second_digest}" ]]

	run tar -tzf "${first_archive}"
	assert_success
	assert_output_contains "mantle-${RELEASE_VERSION}/VERSION"
	assert_output_contains "mantle-${RELEASE_VERSION}/RELEASE-METADATA.json"
	assert_output_contains "mantle-${RELEASE_VERSION}/libexec/mantle/commands/doctor.sh"
	assert_output_not_contains ".git/"

	run tar -xOzf "${first_archive}" "mantle-${RELEASE_VERSION}/VERSION"
	assert_success
	[[ "${output}" == "${RELEASE_VERSION}" ]]

	run "${RELEASE_VERIFY_SCRIPT}" --archive "${first_archive}" --version "${RELEASE_VERSION}"
	assert_success
	assert_output_contains "verified"
}

@test "package-release rejects a version with a leading tag prefix" {
	run python3 "${RELEASE_SCRIPT}" \
		--include-worktree \
		--source-dir "${MANTLE_ROOT}" \
		--version "v0.1.2" \
		--output-dir "${TEST_HOME}/output"
	assert_failure
	assert_output_contains "semantic version"
}

@test "package-release refuses an existing archive without changing its bytes" {
	local output_dir="${TEST_HOME}/immutable"
	local archive="${output_dir}/mantle-${RELEASE_VERSION}.tar.gz"
	local before=""

	run python3 "${RELEASE_SCRIPT}" --include-worktree --source-dir "${MANTLE_ROOT}" \
		--version "${RELEASE_VERSION}" --output-dir "${output_dir}"
	assert_success
	before="$(sha256sum "${archive}" | awk '{print $1}')"
	run python3 "${RELEASE_SCRIPT}" --include-worktree --source-dir "${MANTLE_ROOT}" \
		--version "${RELEASE_VERSION}" --output-dir "${output_dir}"
	assert_failure
	assert_output_contains "already exists"
	[[ "$(sha256sum "${archive}" | awk '{print $1}')" == "${before}" ]]
}

@test "release metadata identifies the tag source archive and Relay evidence" {
	local output_dir="${TEST_HOME}/metadata"
	local archive="${output_dir}/mantle-${RELEASE_VERSION}.tar.gz"

	run python3 "${RELEASE_SCRIPT}" --include-worktree --source-dir "${MANTLE_ROOT}" \
		--version "${RELEASE_VERSION}" --output-dir "${output_dir}"
	assert_success
	run tar -xOzf "${archive}" "mantle-${RELEASE_VERSION}/RELEASE-METADATA.json"
	assert_success
	assert_output_contains "\"tag\": \"v${RELEASE_VERSION}\""
	assert_output_contains "\"archive\": \"mantle-${RELEASE_VERSION}.tar.gz\""
	assert_output_contains 'release-evidence.json'
	assert_output_contains 'release-asset.sha256'
}

@test "copy installation retains an inert release receipt after extraction is removed" {
	local output_dir="${TEST_HOME}/receipt"
	local archive="${output_dir}/mantle-${RELEASE_VERSION}.tar.gz"
	local extracted="${TEST_HOME}/extracted"
	local prefix="${TEST_HOME}/installed"

	run python3 "${RELEASE_SCRIPT}" --include-worktree --source-dir "${MANTLE_ROOT}" \
		--version "${RELEASE_VERSION}" --output-dir "${output_dir}"
	assert_success
	mkdir -p "${extracted}"
	tar -xzf "${archive}" -C "${extracted}"
	run "${extracted}/mantle-${RELEASE_VERSION}/install.sh" \
		--pin "${RELEASE_VERSION}" --prefix "${prefix}" --no-shell-hook
	assert_success
	assert_file_exists "${prefix}/RELEASE-METADATA.json"
	cmp "${prefix}/RELEASE-METADATA.json" "${extracted}/mantle-${RELEASE_VERSION}/RELEASE-METADATA.json"
	rm -rf "${extracted}"
	run "${prefix}/install.sh" --status --prefix "${prefix}"
	assert_success
	assert_output_contains 'release receipt:'
	assert_output_contains "${prefix}/RELEASE-METADATA.json"
	run "${prefix}/bin/mantle" version --short
	assert_success
	[[ "${output}" == "${RELEASE_VERSION}" ]]
}
