#!/usr/bin/env bats
# Offline generated fixtures exercise the public, read-only storage commands.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	setup_stub_dir
	MANTLE_BIN="${MANTLE_ROOT}/bin/mantle"
	STORAGE_FIXTURE="${TEST_HOME}/storage fixture"
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

# @description Invoke storage with an isolated environment.
# @arg $@ string Storage command arguments.
_storage() {
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}:${PATH}" \
		TERM=dumb "${MANTLE_BIN}" storage "$@"
}

# @description Create local disk, sparse-file, link, and optional Git/LFS fixtures.
# @arg $@ string Optional fixture generator flags.
_storage_fixture() {
	if ! command -v python3 >/dev/null 2>&1; then
		skip "python3 is not available"
	fi
	python3 "${MANTLE_ROOT}/tests/fixtures/storage/create-fixture.py" "${STORAGE_FIXTURE}" "$@"
}

# @description Assert JSON semantics using Python and the generated fixture manifest.
# @arg $1 string Trusted Python assertions with report and manifest variables available.
_assert_storage_json() {
	python3 - "${output}" "${STORAGE_FIXTURE}/manifest.json" "$1" <<'PY'
import json
from pathlib import Path
import sys

report = json.loads(sys.argv[1])
manifest_path = Path(sys.argv[2])
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
assert report["schema"] == "egohygiene.mantle.storage/v1", report
assert isinstance(report["complete"], bool), report
assert isinstance(report["data"], dict), report
assert isinstance(report["warnings"], list), report
assert Path(report["path"]).is_absolute(), report
for warning in report["warnings"]:
    assert set(warning) == {"code", "path", "message"}, warning
exec(sys.argv[3])
PY
}

# @description Build a PATH containing only the dispatcher's essential commands.
# @arg $@ string Optional additional tools such as python3 or git.
_storage_minimal_path() {
	local tool
	for tool in bash basename dirname readlink env "$@"; do
		ln -s "$(command -v "${tool}")" "${STUB_DIR}/${tool}"
	done
}

@test "storage help is discoverable and does not require Python" {
	_storage_minimal_path
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" help storage
	assert_success
	assert_output_contains "disk"
	assert_output_contains "directory"
	assert_output_contains "repo"
	assert_output_contains "objects"
	assert_output_contains "large-files"
	assert_output_contains "--json"
}

@test "storage rejects invalid commands options thresholds and extra paths" {
	_storage unknown
	assert_status 64
	_storage directory --limit 2
	assert_status 64
	_storage disk --min-size 1
	assert_status 64
	_storage large-files --limit 0
	assert_status 64
	_storage large-files --limit nope
	assert_status 64
	_storage large-files --min-size -1
	assert_status 64
	_storage directory --unknown
	assert_status 64
	_storage directory one two
	assert_status 64
}

@test "storage disk emits a stable JSON envelope and nonnegative byte counts" {
	_storage_fixture
	_storage disk "${STORAGE_FIXTURE}" --json
	assert_success
	_assert_storage_json '
assert report["command"] == "disk"
assert report["complete"] and report["warnings"] == []
data = report["data"]
assert data["total_bytes"] > 0
assert 0 <= data["free_bytes"] <= data["total_bytes"]
assert 0 <= data["used_bytes"] <= data["total_bytes"]
'
}

@test "storage disk refuses special-file targets without opening or blocking on them" {
	_storage_fixture
	python3 - "${STORAGE_FIXTURE}/named-pipe" <<'PY'
import os
import sys
os.mkfifo(sys.argv[1])
PY
	_storage disk "${STORAGE_FIXTURE}/named-pipe" --json
	assert_status 1
	_assert_storage_json 'assert not report["complete"] and report["warnings"] and report["data"] == {}'
}

@test "storage defaults to the physical current directory and honors dash-leading paths after double dash" {
	_storage_fixture
	cd "${STORAGE_FIXTURE}/directory"
	_storage directory --json
	assert_success
	_assert_storage_json '
assert report["path"] == str(manifest_path.parent / "directory")
assert report["data"]["apparent_bytes"] == manifest["directory"]["apparent_bytes"]
'
	mkdir "${STORAGE_FIXTURE}/--help"
	cd "${STORAGE_FIXTURE}"
	_storage directory --json -- --help
	assert_success
	_assert_storage_json '
assert report["path"] == str(manifest_path.parent / "--help")
assert report["data"]["files"] == 0
'
}

@test "storage directory accounts for hardlinks sparse files and symlinks exactly once" {
	_storage_fixture
	_storage directory "${STORAGE_FIXTURE}/directory" --json
	assert_success
	_assert_storage_json '
assert report["command"] == "directory"
assert report["complete"] and report["warnings"] == []
data = report["data"]
expected = manifest["directory"]
for field in ("apparent_bytes", "files", "directories", "hardlinks", "symlinks"):
    assert data[field] == expected[field], (field, data, expected)
assert data["allocated_bytes"] < data["apparent_bytes"]
assert data["sparse_files"] >= 1
assert data["skipped_mounts"] == 0
'
}

@test "storage large-files sorts by apparent bytes and deduplicates hardlinks" {
	_storage_fixture
	_storage large-files "${STORAGE_FIXTURE}/directory" --json --limit 100 --min-size 1
	assert_success
	_assert_storage_json '
assert report["command"] == "large-files"
assert report["complete"]
data = report["data"]
assert data["scanned_files"] == manifest["directory"]["files"]
assert len(data["files"]) == data["scanned_files"]
sizes = [entry["apparent_bytes"] for entry in data["files"]]
assert sizes == sorted(sizes, reverse=True), data
assert sizes.count(2 * 1024 * 1024) == 1, data
assert data["files"][0]["path"] == "sparse.bin", data
'
}

@test "storage large-files applies its limit and inclusive byte threshold" {
	_storage_fixture
	_storage large-files "${STORAGE_FIXTURE}/directory" --json --limit 1 --min-size 33554432
	assert_success
	_assert_storage_json '
data = report["data"]
assert report["complete"]
assert data["limit"] == 1 and data["min_size_bytes"] == 33554432
assert data["scanned_files"] == manifest["directory"]["files"]
assert [entry["path"] for entry in data["files"]] == ["sparse.bin"]
'
	_storage large-files "${STORAGE_FIXTURE}/directory" --json --min-size 33554433
	assert_success
	_assert_storage_json 'assert report["data"]["files"] == []'
}

@test "storage preserves control-character filenames in JSON and escapes human output" {
	_storage_fixture
	_storage large-files "${STORAGE_FIXTURE}/directory" --json --limit 100 --min-size 0
	assert_success
	_assert_storage_json '
paths = [entry["path"] for entry in report["data"]["files"]]
assert manifest["directory"]["control_filename"] in paths, paths
'
	[[ "${output}" != *$'\033'* ]]
	_storage large-files "${STORAGE_FIXTURE}/directory" --limit 100 --min-size 0
	assert_success
	[[ "${output}" != *$'\033'* ]]
	assert_output_contains 'line\nbreak\u001b[31m.txt'
}

@test "storage refuses a symbolic link target and a symbolic link path component" {
	_storage_fixture
	ln -s "${STORAGE_FIXTURE}/directory" "${STORAGE_FIXTURE}/linked-root"
	_storage directory "${STORAGE_FIXTURE}/linked-root" --json
	assert_status 1
	_assert_storage_json 'assert not report["complete"] and report["warnings"]'
	_storage directory "${STORAGE_FIXTURE}/linked-root/nested" --json
	assert_status 1
	_assert_storage_json 'assert not report["complete"] and report["warnings"]'
}

@test "storage refuses symlinks before resolving dot dot path components" {
	_storage_fixture
	ln -s "${STORAGE_FIXTURE}/outside" "${STORAGE_FIXTURE}/linked-root"
	_storage directory "${STORAGE_FIXTURE}/linked-root/../directory" --json
	assert_status 1
	_assert_storage_json 'assert not report["complete"] and report["warnings"]'
}

@test "storage reports missing and non-directory targets without a traceback" {
	_storage_fixture
	_storage directory "${STORAGE_FIXTURE}/missing" --json
	assert_status 1
	_assert_storage_json 'assert not report["complete"] and report["warnings"]'
	assert_output_not_contains "Traceback"
	_storage directory "${STORAGE_FIXTURE}/directory/small.txt" --json
	assert_status 1
	_assert_storage_json 'assert not report["complete"] and report["warnings"]'
}

@test "storage permission failures remain explicit partial results even under root" {
	_storage_fixture
	run python3 "${MANTLE_ROOT}/tests/fixtures/storage/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/storage.py" "${STORAGE_FIXTURE}/directory" permission
	assert_status 1
	_assert_storage_json '
assert not report["complete"]
assert any(warning["code"] == "permission_denied" for warning in report["warnings"])
assert report["data"]["apparent_bytes"] == manifest["directory"]["apparent_bytes"] - 4096
'
}

@test "storage does not cross filesystem boundaries without requiring real mounts" {
	_storage_fixture
	run python3 "${MANTLE_ROOT}/tests/fixtures/storage/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/storage.py" "${STORAGE_FIXTURE}/directory" device
	assert_status 1
	_assert_storage_json '
assert not report["complete"]
assert any(warning["code"] == "filesystem_boundary" for warning in report["warnings"])
assert report["data"]["skipped_mounts"] == 1
assert report["data"]["apparent_bytes"] == manifest["directory"]["apparent_bytes"] - 4096
'
}

@test "storage exposes unavailable allocation as null instead of substituting logical size" {
	_storage_fixture
	run python3 "${MANTLE_ROOT}/tests/fixtures/storage/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/storage.py" "${STORAGE_FIXTURE}/directory" allocation
	assert_status 1
	_assert_storage_json '
assert not report["complete"]
assert any(warning["code"] == "allocation_unavailable" for warning in report["warnings"])
assert report["data"]["allocated_bytes"] is None
assert report["data"]["apparent_bytes"] == manifest["directory"]["apparent_bytes"]
'
}

@test "storage directory stays inside its requested tree and prunes nested repositories" {
	_storage_fixture
	mkdir -p "${STORAGE_FIXTURE}/directory/embedded/.git"
	printf "nested repository file\n" >"${STORAGE_FIXTURE}/directory/embedded/skip.txt"
	_storage directory "${STORAGE_FIXTURE}/directory" --json
	assert_success
	_assert_storage_json '
assert report["complete"]
data = report["data"]
assert data["apparent_bytes"] == manifest["directory"]["apparent_bytes"]
assert data["skipped_repositories"] == 1
'
}

@test "storage includes ordinary root Git metadata but prunes a nested repository named dot git" {
	_storage_fixture
	mkdir "${STORAGE_FIXTURE}/directory/.git"
	printf "metadata\n" >"${STORAGE_FIXTURE}/directory/.git/config"
	_storage directory "${STORAGE_FIXTURE}/directory" --json
	assert_success
	_assert_storage_json '
assert report["data"]["apparent_bytes"] == manifest["directory"]["apparent_bytes"] + 9
assert report["data"]["skipped_repositories"] == 0
'
	mkdir "${STORAGE_FIXTURE}/directory/.git/.git"
	_storage directory "${STORAGE_FIXTURE}/directory" --json
	assert_success
	_assert_storage_json '
assert report["complete"]
assert report["data"]["apparent_bytes"] == manifest["directory"]["apparent_bytes"]
assert report["data"]["skipped_repositories"] == 1
'
}

@test "storage reports a missing Python dependency only when storage is used" {
	_storage_minimal_path
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" storage directory "${TEST_HOME}"
	assert_status 69
	assert_output_contains "Python"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" version
	assert_success
}

@test "storage filesystem and repository commands work without Git installed" {
	_storage_fixture --repository
	_storage_minimal_path python3
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" storage directory "${STORAGE_FIXTURE}/directory" --json
	assert_success
	_assert_storage_json 'assert report["complete"]'
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" storage repo "${STORAGE_FIXTURE}/repository" --json
	assert_success
	_assert_storage_json 'assert report["complete"] and report["data"]["objects"]["loose"]["count"] > 0'
}

@test "storage repo separates worktree Git object and LFS cache sizes" {
	_storage_fixture --repository
	_storage repo "${STORAGE_FIXTURE}/repository" --json
	assert_success
	_assert_storage_json '
assert report["command"] == "repo" and report["complete"]
data = report["data"]
expected = manifest["repository"]
assert data["worktree"]["files"] == 2, data
assert data["worktree"]["apparent_bytes"] < expected["lfs_bytes"]
assert data["git"]["apparent_bytes"] >= expected["lfs_bytes"]
assert data["objects"]["loose"]["count"] > 0
assert data["lfs"]["cache"]["apparent_bytes"] == expected["lfs_bytes"]
assert data["lfs"]["pointers"]["count"] == 1
assert data["lfs"]["pointers"]["declared_bytes"] == expected["lfs_bytes"]
assert data["lfs"]["pointers"]["files"][0] == {
    "path": "asset.lfs", "size_bytes": expected["lfs_bytes"], "oid": "sha256:" + expected["lfs_oid"]
}, data
'
}

@test "storage preserves repository measurements when the optional LFS cache is unreadable" {
	_storage_fixture --repository
	run python3 "${MANTLE_ROOT}/tests/fixtures/storage/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/storage.py" "${STORAGE_FIXTURE}/repository" lfs-permission
	assert_status 1
	_assert_storage_json '
assert not report["complete"]
assert any(warning["code"] == "permission_denied" for warning in report["warnings"])
assert report["data"]["worktree"]["files"] == 2
assert report["data"]["objects"]["loose"]["count"] > 0
assert report["data"]["lfs"]["cache"]["files"] == 0
'
}

@test "storage objects distinguishes packed objects from pack indexes" {
	_storage_fixture --repository
	# Git repack exposes these two options only in short form.
	git -C "${STORAGE_FIXTURE}/repository" repack -a -d --quiet
	_storage objects "${STORAGE_FIXTURE}/repository" --json
	assert_success
	_assert_storage_json '
assert report["command"] == "objects" and report["complete"]
data = report["data"]
assert data["packs"]["count"] == 1, data
assert data["packs"]["apparent_bytes"] > 0, data
assert data["loose"]["count"] == 0, data
assert data["other"]["count"] >= 1, data
'
}

@test "storage rejects gitfile worktrees and symbolic link Git metadata" {
	_storage_fixture --repository
	local external="${STORAGE_FIXTURE}/external.git"
	mv "${STORAGE_FIXTURE}/repository/.git" "${external}"
	printf "gitdir: %s\n" "${external}" >"${STORAGE_FIXTURE}/repository/.git"
	_storage repo "${STORAGE_FIXTURE}/repository" --json
	assert_status 1
	_assert_storage_json 'assert not report["complete"] and report["warnings"]'
	rm "${STORAGE_FIXTURE}/repository/.git"
	ln -s "${external}" "${STORAGE_FIXTURE}/repository/.git"
	_storage objects "${STORAGE_FIXTURE}/repository" --json
	assert_status 1
	_assert_storage_json 'assert not report["complete"] and report["warnings"]'
}

@test "storage object accounting does not follow alternate object stores" {
	_storage_fixture --repository
	mkdir -p "${STORAGE_FIXTURE}/repository/.git/objects/info"
	printf "%s\n" "${STORAGE_FIXTURE}/outside" >"${STORAGE_FIXTURE}/repository/.git/objects/info/alternates"
	_storage objects "${STORAGE_FIXTURE}/repository" --json
	assert_status 1
	_assert_storage_json '
assert not report["complete"] and report["warnings"]
data = report["data"]
assert sum(group["apparent_bytes"] for group in data.values()) < 256 * 1024 * 1024, data
'
}

@test "storage reports a symbolic link inside Git object metadata as an incomplete boundary" {
	_storage_fixture --repository
	rmdir "${STORAGE_FIXTURE}/repository/.git/objects/pack"
	ln -s "${STORAGE_FIXTURE}/outside" "${STORAGE_FIXTURE}/repository/.git/objects/pack"
	_storage objects "${STORAGE_FIXTURE}/repository" --json
	assert_status 1
	_assert_storage_json '
assert not report["complete"]
assert any(warning["code"] == "git_metadata_boundary" for warning in report["warnings"])
data = report["data"]
assert data["loose"]["count"] > 0 and data["packs"]["count"] == 0
assert sum(group["apparent_bytes"] for group in data.values()) < 256 * 1024 * 1024, data
'
}

@test "storage ignores inherited Git redirection and never executes configured helpers" {
	_storage_fixture --repository
	local marker="${STORAGE_FIXTURE}/unexpected-helper"
	git -C "${STORAGE_FIXTURE}/repository" config core.fsmonitor "touch ${marker}"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}:${PATH}" \
		GIT_DIR="${STORAGE_FIXTURE}/outside" GIT_WORK_TREE="${STORAGE_FIXTURE}/outside" \
		GIT_OBJECT_DIRECTORY="${STORAGE_FIXTURE}/outside" GIT_CONFIG_COUNT=1 \
		GIT_CONFIG_KEY_0=core.bare GIT_CONFIG_VALUE_0=true \
		"${MANTLE_BIN}" storage repo "${STORAGE_FIXTURE}/repository" --json
	assert_success
	_assert_storage_json 'assert report["complete"] and report["data"]["worktree"]["files"] == 2'
	assert_file_not_exists "${marker}"
}
