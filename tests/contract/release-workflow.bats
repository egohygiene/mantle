#!/usr/bin/env bats
# Contract tests for Mantle's signed-release publication boundary.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	RELEASE_WORKFLOW="${MANTLE_ROOT}/.github/workflows/release.yml"
}

@test "release workflow publishes only tagged, verified source distributions" {
	assert_file_exists "${RELEASE_WORKFLOW}"
	run grep -F 'tags:' "${RELEASE_WORKFLOW}"
	assert_success
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

@test "release workflow safely creates or updates the tagged GitHub release" {
	run grep -F 'gh release view "${GITHUB_REF_NAME}"' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -F 'gh release upload "${GITHUB_REF_NAME}"' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -F -- '--clobber' "${RELEASE_WORKFLOW}"
	assert_success
	run grep -F 'gh release create "${GITHUB_REF_NAME}"' "${RELEASE_WORKFLOW}"
	assert_success
}
