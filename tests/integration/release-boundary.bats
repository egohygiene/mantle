#!/usr/bin/env bats
# Copyright 2026 Ego Hygiene
# SPDX-License-Identifier: MIT
# Offline adversarial controls for release archive and installer evidence boundaries.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	RELEASE_SCRIPT="${MANTLE_ROOT}/scripts/package-release.py"
	RELEASE_VERSION="0.1.2"
}

teardown() {
	teardown_isolated_home
}

_release_source_fixture() {
	RELEASE_SOURCE="${TEST_HOME}/source"
	mkdir -p "${RELEASE_SOURCE}"
	printf 'development\n' >"${RELEASE_SOURCE}/VERSION"
	printf '# Synthetic source\n' >"${RELEASE_SOURCE}/README.md"
	git -C "${RELEASE_SOURCE}" init --quiet
	git -C "${RELEASE_SOURCE}" add VERSION README.md
	git -C "${RELEASE_SOURCE}" -c user.name=Fixture -c user.email=fixture@example.invalid \
		commit --quiet --message 'Synthetic release fixture'
}

_installer_source_fixture() {
	local item=""
	RELEASE_SOURCE="${TEST_HOME}/installer-source"
	mkdir -p "${RELEASE_SOURCE}"
	for item in .shellrc VERSION install.sh README.md LICENSE bin lib libexec init modules platforms runtime assets config docs; do
		cp -R "${MANTLE_ROOT}/${item}" "${RELEASE_SOURCE}/${item}"
	done
	printf '%s\n' "${RELEASE_VERSION}" >"${RELEASE_SOURCE}/VERSION"
}

@test "release archive rejects preexisting symlink hardlink and directory targets" {
	local kind=""
	local output_dir=""
	local archive=""
	_release_source_fixture
	printf 'preexisting immutable bytes\n' >"${TEST_HOME}/sentinel"
	for kind in symlink hardlink directory; do
		output_dir="${TEST_HOME}/${kind}"
		archive="${output_dir}/mantle-${RELEASE_VERSION}.tar.gz"
		mkdir -p "${output_dir}"
		case "${kind}" in
		symlink) ln -s "${TEST_HOME}/sentinel" "${archive}" ;;
		hardlink) ln "${TEST_HOME}/sentinel" "${archive}" ;;
		directory) mkdir "${archive}" ;;
		esac
		run python3 "${RELEASE_SCRIPT}" --source-dir "${RELEASE_SOURCE}" \
			--version "${RELEASE_VERSION}" --output-dir "${output_dir}"
		assert_failure
		assert_output_not_contains 'Traceback'
		case "${kind}" in
		symlink) [[ -L "${archive}" ]] ;;
		hardlink) [[ "${archive}" -ef "${TEST_HOME}/sentinel" ]] ;;
		directory) [[ -d "${archive}" ]] ;;
		esac
	done
	[[ "$(cat "${TEST_HOME}/sentinel")" == 'preexisting immutable bytes' ]]
}

@test "release archive preserves a competing publication at the final write seam" {
	_release_source_fixture
	run python3 - "${RELEASE_SCRIPT}" "${RELEASE_SOURCE}" "${TEST_HOME}/racing" <<'PY'
import hashlib
import importlib.util
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location("mantle_release_race", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
source, output = Path(sys.argv[2]), Path(sys.argv[3])
before = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source.iterdir() if p.is_file()}
winner = b"concurrent immutable publication\n"
injected = []
original_link, original_replace = module.os.link, module.os.replace

# Trusted deterministic seam injection; this does not claim a real host race.
def collide(operation):
    def publish(temporary, destination, *args, **kwargs):
        Path(destination).write_bytes(winner)
        injected.append(True)
        return operation(temporary, destination, *args, **kwargs)
    return publish

module.os.link = collide(original_link)
module.os.replace = collide(original_replace)
rejected = False
try:
    module.build_archive(source, output, "0.1.2", False)
except (RuntimeError, FileExistsError):
    rejected = True
finally:
    module.os.link, module.os.replace = original_link, original_replace
assert injected, "publication seam was not exercised"
assert rejected, "competing publication was not rejected"
assert (output / "mantle-0.1.2.tar.gz").read_bytes() == winner
assert not list(output.glob(".mantle-*.tmp")), "temporary archive leaked"
after = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source.iterdir() if p.is_file()}
assert before == after, "packaging changed source bytes"
PY
	assert_success
}

@test "generated release receipt has one canonical archive member in both source selection modes" {
	local mode=""
	_release_source_fixture
	printf '{"untrusted":"authored receipt must not be archived"}\n' >"${RELEASE_SOURCE}/RELEASE-METADATA.json"
	git -C "${RELEASE_SOURCE}" add RELEASE-METADATA.json
	git -C "${RELEASE_SOURCE}" -c user.name=Fixture -c user.email=fixture@example.invalid \
		commit --quiet --message 'Synthetic reserved receipt fixture'
	for mode in tracked worktree untracked; do
		if [[ "${mode}" == untracked ]]; then
			git -C "${RELEASE_SOURCE}" rm --cached --quiet RELEASE-METADATA.json
			git -C "${RELEASE_SOURCE}" -c user.name=Fixture -c user.email=fixture@example.invalid \
				commit --quiet --message 'Synthetic untracked receipt fixture'
		fi
		if [[ "${mode}" != tracked ]]; then
			run python3 "${RELEASE_SCRIPT}" --include-worktree --source-dir "${RELEASE_SOURCE}" \
				--version "${RELEASE_VERSION}" --output-dir "${TEST_HOME}/${mode}"
		else
			run python3 "${RELEASE_SCRIPT}" --source-dir "${RELEASE_SOURCE}" \
				--version "${RELEASE_VERSION}" --output-dir "${TEST_HOME}/${mode}"
		fi
		assert_success
		run python3 - "${TEST_HOME}/${mode}/mantle-${RELEASE_VERSION}.tar.gz" <<'PY'
import json
import sys
import tarfile
with tarfile.open(sys.argv[1]) as archive:
    receipts = [member for member in archive.getmembers() if member.name.endswith("/RELEASE-METADATA.json")]
    assert len(receipts) == 1, "reserved receipt was duplicated"
    document = json.load(archive.extractfile(receipts[0]))
    assert "untrusted" not in document
    assert document["version"] == "0.1.2"
PY
		assert_success
	done
}

@test "development source installation does not require a release receipt" {
	_installer_source_fixture
	run "${RELEASE_SOURCE}/install.sh" --prefix "${TEST_HOME}/installed" --no-shell-hook
	assert_success
	assert_file_not_exists "${TEST_HOME}/installed/RELEASE-METADATA.json"
	run env -u MANTLE_ROOT "${TEST_HOME}/installed/bin/mantle" version --short
	assert_success
	[[ "${output}" == "${RELEASE_VERSION}" ]]
}

@test "copied release receipt is inert and cannot become a version authority" {
	_installer_source_fixture
	# shellcheck disable=SC2016 # The forged receipt must retain literal shell syntax as inert data.
	printf '{"version":"9.9.9","tag":"v9.9.9","forged":"$(touch %s)"}\n' "${TEST_HOME}/receipt-executed" \
		>"${RELEASE_SOURCE}/RELEASE-METADATA.json"
	run "${RELEASE_SOURCE}/install.sh" --pin "${RELEASE_VERSION}" \
		--prefix "${TEST_HOME}/installed" --no-shell-hook
	assert_success
	cmp "${RELEASE_SOURCE}/RELEASE-METADATA.json" "${TEST_HOME}/installed/RELEASE-METADATA.json"
	assert_file_not_exists "${TEST_HOME}/receipt-executed"
	run env -u MANTLE_ROOT "${TEST_HOME}/installed/bin/mantle" version --short
	assert_success
	[[ "${output}" == "${RELEASE_VERSION}" ]]
}

@test "forged receipt and environment override cannot satisfy a mismatched source pin" {
	_installer_source_fixture
	printf '0.0.0\n' >"${RELEASE_SOURCE}/VERSION"
	printf '{"version":"0.1.2","tag":"v0.1.2","verified":true}\n' \
		>"${RELEASE_SOURCE}/RELEASE-METADATA.json"
	run env MANTLE_VERSION="${RELEASE_VERSION}" "${RELEASE_SOURCE}/install.sh" \
		--pin "${RELEASE_VERSION}" --prefix "${TEST_HOME}/installed" --no-shell-hook
	assert_failure
	assert_output_contains 'release pin does not match this source'
	assert_file_not_exists "${TEST_HOME}/installed"
}

@test "development update removes an earlier optional release receipt without breaking doctor" {
	_installer_source_fixture
	printf '{"version":"0.1.2","authentication":"not-verified"}\n' \
		>"${RELEASE_SOURCE}/RELEASE-METADATA.json"
	run "${RELEASE_SOURCE}/install.sh" --prefix "${TEST_HOME}/installed" --no-shell-hook
	assert_success
	assert_file_exists "${TEST_HOME}/installed/RELEASE-METADATA.json"
	rm "${RELEASE_SOURCE}/RELEASE-METADATA.json"
	run "${RELEASE_SOURCE}/install.sh" --update --pin "${RELEASE_VERSION}" \
		--prefix "${TEST_HOME}/installed" --no-shell-hook
	assert_success
	assert_file_not_exists "${TEST_HOME}/installed/RELEASE-METADATA.json"
	run "${TEST_HOME}/installed/install.sh" --doctor --prefix "${TEST_HOME}/installed" --no-shell-hook
	assert_success
}

@test "failed update publication restores the prior receipt and installer metadata bytes" {
	local real_mv=""
	local stub_dir="${TEST_HOME}/failing-bin"
	local counter="${TEST_HOME}/mv.count"
	_installer_source_fixture
	printf '{"version":"0.1.2","authentication":"not-verified"}\n' \
		>"${RELEASE_SOURCE}/RELEASE-METADATA.json"
	run "${RELEASE_SOURCE}/install.sh" --prefix "${TEST_HOME}/installed" --no-shell-hook
	assert_success
	cp "${TEST_HOME}/installed/RELEASE-METADATA.json" "${TEST_HOME}/receipt-before.json"
	cp "${TEST_HOME}/installed/.mantle-installer" "${TEST_HOME}/installer-before.json"
	printf '0.1.3\n' >"${RELEASE_SOURCE}/VERSION"
	printf '{"version":"0.1.3","authentication":"not-verified"}\n' \
		>"${RELEASE_SOURCE}/RELEASE-METADATA.json"
	real_mv="$(command -v mv)"
	mkdir -p "${stub_dir}"
	cat >"${stub_dir}/mv" <<EOF
#!/bin/sh
count=0
if [ -f "${counter}" ]; then count=\$(cat "${counter}"); fi
count=\$((count + 1))
printf '%s\n' "\${count}" >"${counter}"
if [ "\${count}" -eq 2 ]; then exit 1; fi
exec "${real_mv}" "\$@"
EOF
	chmod 0755 "${stub_dir}/mv"
	run env PATH="${stub_dir}:${PATH}" "${RELEASE_SOURCE}/install.sh" \
		--update --pin 0.1.3 --prefix "${TEST_HOME}/installed" --no-shell-hook
	assert_failure
	[[ "$(cat "${counter}")" -ge 3 ]]
	cmp "${TEST_HOME}/receipt-before.json" "${TEST_HOME}/installed/RELEASE-METADATA.json"
	cmp "${TEST_HOME}/installer-before.json" "${TEST_HOME}/installed/.mantle-installer"
	[[ "$(cat "${TEST_HOME}/installed/VERSION")" == "${RELEASE_VERSION}" ]]
	run python3 - "${TEST_HOME}" <<'PY'
from pathlib import Path
import sys
assert not list(Path(sys.argv[1]).glob("installed.previous.*"))
PY
	assert_success
}
