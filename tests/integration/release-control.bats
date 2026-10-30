#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Local release preparation, never Task execution or remote publication.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	CONTROL="${MANTLE_ROOT}/scripts/release-control.py"
	SOURCE="${TEST_HOME}/source with spaces"
	mkdir -p "${SOURCE}/.egohygiene"
	git -C "${SOURCE}" init --quiet
	git -C "${SOURCE}" config core.hooksPath /dev/null
	cp "${MANTLE_ROOT}/.egohygiene/release.json" "${SOURCE}/.egohygiene/release.json"
	printf '%s\n' '0.1.0-dev' >"${SOURCE}/VERSION"
	printf '# Changelog\n\n## [Unreleased]\n\n### Added\n\n- Synthetic source.\n' >"${SOURCE}/CHANGELOG.md"
	printf '%s\n' 'synthetic source bytes' >"${SOURCE}/README.md"
	_commit_fixture
	REVISION="$(git -C "${SOURCE}" rev-parse HEAD)"
}

teardown() {
	teardown_isolated_home
}

_commit_fixture() {
	git -C "${SOURCE}" add --all
	git -C "${SOURCE}" -c user.name='Release Fixture' -c user.email=fixture@example.invalid \
		-c commit.gpgsign=false commit --quiet --allow-empty --message 'synthetic release fixture'
}

_build_archive() {
	python3 "${MANTLE_ROOT}/scripts/package-release.py" --source-dir "${SOURCE}" \
		--version 0.1.2 --output-dir "${TEST_HOME}/archive with spaces" >/dev/null
	ARCHIVE="${TEST_HOME}/archive with spaces/mantle-0.1.2.tar.gz"
}

@test "release planning rejects unsupported versions before mutation" {
	local candidate=""
	for candidate in '0.1.2' 'v01.1.2' 'v0.1.2-dev' 'v0.1.2+build' 'v0.1.2;touch forbidden'; do
		run python3 "${CONTROL}" plan --repository "${SOURCE}" --version "${candidate}"
		assert_failure
		assert_output_contains 'exact stable'
	done
	[[ "$(git -C "${SOURCE}" status --porcelain)" == '' ]]
}

@test "plan and prepare print reviewable evidence without changing source" {
	run python3 "${CONTROL}" plan --repository "${SOURCE}" --version v0.1.2
	assert_success
	assert_output_contains 'unavailable-locally'
	assert_output_contains 'not-authenticated-locally'
	assert_output_contains 'not-performed'
	run python3 "${CONTROL}" prepare --repository "${SOURCE}" --version v0.1.2 --date 2026-10-30
	assert_success
	assert_output_contains '--- a/CHANGELOG.md'
	assert_output_contains '+## [0.1.2] - 2026-10-30'
	[[ "$(git -C "${SOURCE}" status --porcelain)" == '' ]]
	[[ "$(cat "${SOURCE}/VERSION")" == '0.1.0-dev' ]]
	run python3 "${CONTROL}" prepare --repository "${SOURCE}" --version v0.1.2 --date 2026-02-30
	assert_failure
}

@test "local verification needs a promoted clean exact source and still does not authenticate publication" {
	run python3 "${CONTROL}" verify --repository "${SOURCE}" --version v0.1.2
	assert_failure
	assert_output_contains 'dated changelog promotion'
	printf '\n## [0.1.2] - 2026-10-30\n\n### Added\n\n- Synthetic reviewed change.\n' >>"${SOURCE}/CHANGELOG.md"
	_commit_fixture
	REVISION="$(git -C "${SOURCE}" rev-parse HEAD)"
	run python3 "${CONTROL}" verify --repository "${SOURCE}" --version v0.1.2 --source-revision "${REVISION}"
	assert_success
	assert_output_contains 'verified-local'
	assert_output_contains 'not-authenticated-locally'
	run python3 "${CONTROL}" verify --repository "${SOURCE}" --version v0.1.2 --source-revision 1111111111111111111111111111111111111111
	assert_failure
	printf '%s\n' changed >>"${SOURCE}/README.md"
	run python3 "${CONTROL}" verify --repository "${SOURCE}" --version v0.1.2
	assert_failure
	assert_output_contains 'clean tracked source'
}

@test "unsigned source evidence has a complete sorted checksum inventory and honest states" {
	_build_archive
	run python3 "${CONTROL}" evidence --version v0.1.2 --source-revision "${REVISION}" \
		--archive "${ARCHIVE}" --output-dir "${TEST_HOME}/bundle"
	assert_success
	assert_output_contains 'unavailable'
	run python3 - "${TEST_HOME}/bundle" <<'PYTHON'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1])
expected=''.join(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n' for path in sorted(root.iterdir()) if path.name!='SHA256SUMS')
assert (root/'SHA256SUMS').read_text()==expected
assert json.loads((root/'signature.json').read_text())['state']=='unavailable'
assert json.loads((root/'signature.json').read_text())['verification']=='not-performed-by-evidence-writer'
assert json.loads((root/'provenance.json').read_text())['attestation_state']=='unavailable'
assert json.loads((root/'sbom.spdx.json').read_text())['files']
PYTHON
	assert_success
}

@test "recording supplied signature bytes does not claim cryptographic verification" {
	_build_archive
	printf '%s\n' 'synthetic not-a-signature' >"${TEST_HOME}/signature.json"
	run python3 "${CONTROL}" evidence --version v0.1.2 --source-revision "${REVISION}" \
		--archive "${ARCHIVE}" --output-dir "${TEST_HOME}/bundle" --signature-bundle "${TEST_HOME}/signature.json"
	assert_success
	assert_output_contains 'recorded-not-verified'
	run grep -F 'not-performed-by-evidence-writer' "${TEST_HOME}/bundle/signature.json"
	assert_success
}

@test "source evidence rejects mismatches and existing output without altering it" {
	_build_archive
	run python3 "${CONTROL}" evidence --version v0.1.2 --source-revision 1111111111111111111111111111111111111111 \
		--archive "${ARCHIVE}" --output-dir "${TEST_HOME}/wrong"
	assert_failure
	[[ ! -e "${TEST_HOME}/wrong" ]]
	mkdir -p "${TEST_HOME}/existing"
	printf sentinel >"${TEST_HOME}/existing/owned"
	run python3 "${CONTROL}" evidence --version v0.1.2 --source-revision "${REVISION}" \
		--archive "${ARCHIVE}" --output-dir "${TEST_HOME}/existing"
	assert_failure
	[[ "$(cat "${TEST_HOME}/existing/owned")" == sentinel ]]
}

@test "qualification accepts only supplied exact-source manual Linux macOS and static success" {
	python3 - "${TEST_HOME}" "${REVISION}" <<'PYTHON'
import json,sys
from pathlib import Path
root=Path(sys.argv[1]);sha=sys.argv[2]
run={'id':11,'path':'.github/workflows/test.yml','head_sha':sha,'head_branch':'main','event':'workflow_dispatch','status':'completed','conclusion':'success'}
jobs=[{'name':name,'run_id':11,'head_sha':sha,'status':'completed','conclusion':'success'} for name in ['Static Validation','Tests (Linux)','Tests (macOS)']]
(root/'runs.json').write_text(json.dumps({'workflow_runs':[run]}));(root/'jobs.json').write_text(json.dumps({'jobs':jobs}))
PYTHON
	run python3 "${CONTROL}" qualification --version v0.1.2 --source-revision "${REVISION}" \
		--runs-file "${TEST_HOME}/runs.json" --jobs-file "${TEST_HOME}/jobs.json"
	assert_success
	assert_output_contains 'caller-owned-github-api'
	local mutation=""
	for mutation in stale-source pr-event missing-macos failed-macos wrong-run incomplete-job; do
		python3 - "${TEST_HOME}" "${mutation}" <<'PYTHON'
import json,sys
from pathlib import Path
root=Path(sys.argv[1]);mutation=sys.argv[2]
runs=json.loads((root/'runs.json').read_text());jobs=json.loads((root/'jobs.json').read_text())
if mutation=='stale-source':runs['workflow_runs'][0]['head_sha']='1'*40
elif mutation=='pr-event':runs['workflow_runs'][0]['event']='pull_request'
elif mutation=='missing-macos':jobs['jobs'].pop()
elif mutation=='failed-macos':jobs['jobs'][-1]['conclusion']='failure'
elif mutation=='wrong-run':jobs['jobs'][-1]['run_id']=12
elif mutation=='incomplete-job':jobs['jobs'][-1]['status']='in_progress'
(root/'bad-runs.json').write_text(json.dumps(runs));(root/'bad-jobs.json').write_text(json.dumps(jobs))
PYTHON
		run python3 "${CONTROL}" qualification --version v0.1.2 --source-revision "${REVISION}" \
			--runs-file "${TEST_HOME}/bad-runs.json" --jobs-file "${TEST_HOME}/bad-jobs.json"
		assert_failure
	done
}
