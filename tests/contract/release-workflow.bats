#!/usr/bin/env bats
# Contract tests for Mantle's signed-release publication boundary.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	RELEASE_WORKFLOW="${MANTLE_ROOT}/.github/workflows/release.yml"
}

@test "release workflow builds verified source distributions" {
	assert_file_exists "${RELEASE_WORKFLOW}"
	run grep -F 'scripts/package-release.py' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -F 'scripts/verify-release.sh' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -F 'sha256sum' "${RELEASE_WORKFLOW}"
	assert_success
}

@test "release workflow creates keyless signatures and provenance attestations" {
	run grep -F 'cosign sign-blob --yes' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -F 'actions/attest-build-provenance@' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -F 'id-token: write' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -F 'attestations: write' "${RELEASE_WORKFLOW}"
	assert_success
}

@test "release workflow never overwrites immutable release assets" {
	run grep -F -- '--clobber' "${RELEASE_WORKFLOW}"
	assert_failure
	run grep -F 'egohygiene/relay/.github/workflows/semantic-release.yml@1eada5142f7fc7da7862f335589e3b8f5884ffaf' "${RELEASE_WORKFLOW}"
	assert_success
}

@test "release workflow is manual and bound to the current default branch" {
	run grep -F 'workflow_dispatch:' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -E '^[[:space:]]+push:' "${RELEASE_WORKFLOW}"
	assert_failure
	run grep -F 'github.event.repository.default_branch' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -F 'expected-source-revision:' "${RELEASE_WORKFLOW}"
	assert_success
}
