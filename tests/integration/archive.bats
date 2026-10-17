#!/usr/bin/env bats
# Offline project archive selection, publication, and extraction safety.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	setup_isolated_home
	setup_stub_dir
	MANTLE_BIN="${MANTLE_ROOT}/bin/mantle"
	ARCHIVE_FIXTURE="${TEST_HOME}/archive fixture"
	ARCHIVE_PROJECT="${ARCHIVE_FIXTURE}/project"
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

# @description Invoke project archiving with an isolated environment.
# @arg $@ string Archive command arguments.
_archive() {
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}:${PATH}" \
		TERM=dumb "${MANTLE_BIN}" archive "$@"
}

# @description Generate temporary project files and optional real Git metadata.
# @arg $@ string Optional fixture generator flags.
_archive_fixture() {
	if ! command -v python3 >/dev/null 2>&1; then
		skip "python3 is not available"
	fi
	python3 "${MANTLE_ROOT}/tests/fixtures/archive/create-fixture.py" "${ARCHIVE_FIXTURE}" "$@"
}

# @description Assert the report contract and trusted Python conditions.
# @arg $1 string Python assertions with report, included, and excluded available.
_assert_archive_json() {
	python3 - "${output}" "$1" <<'PY'
import json
from pathlib import Path
import sys

report = json.loads(sys.argv[1])
assert report["schema"] == "egohygiene.mantle.archive/v1", report
assert Path(report["path"]).is_absolute(), report
assert isinstance(report["complete"], bool), report
assert report["selection_mode"] in ("git", "filesystem"), report
included = {entry["path"]: entry for entry in report["included"]}
excluded = {entry["path"]: entry for entry in report["excluded"]}
assert len(included) == len(report["included"]), report
assert report["totals"]["files"] == len(included), report
assert report["totals"]["bytes"] == sum(entry["size_bytes"] for entry in included.values()), report
for warning in report["warnings"]:
    assert set(warning) == {"code", "path", "message"}, warning
exec(sys.argv[2])
PY
}

# @description Build a PATH with dispatch essentials and selected optional tools.
# @arg $@ string Additional tools to expose.
_archive_minimal_path() {
	local tool
	for tool in bash basename dirname readlink env "$@"; do
		ln -s "$(command -v "${tool}")" "${STUB_DIR}/${tool}"
	done
}

@test "archive help is discoverable without Python" {
	_archive_minimal_path
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" help archive
	assert_success
	assert_output_contains "--dry-run"
	assert_output_contains "--output"
	assert_output_contains "--include"
	assert_output_contains "--reproducible"
}

@test "archive requires an explicit action and rejects unsafe include arguments" {
	_archive
	assert_status 64
	_archive --unknown
	assert_status 64
	_archive --dry-run --include ../outside.txt
	assert_status 64
	_archive --dry-run --include /outside.txt
	assert_status 64
}

@test "archive filesystem dry-run applies common filters and safety boundaries without writes" {
	_archive_fixture
	python3 - "${ARCHIVE_FIXTURE}" >"${TEST_HOME}/before.json" <<'PY'
import json
from pathlib import Path
import sys
print(json.dumps(sorted(str(path.relative_to(sys.argv[1])) for path in Path(sys.argv[1]).rglob("*"))))
PY
	_archive "${ARCHIVE_PROJECT}" --dry-run --json
	assert_success
	_assert_archive_json '
assert report["complete"] and report["warnings"] == []
assert report["dry_run"] and report["sha256"] is None and report["output"] is None
assert report["selection_mode"] == "filesystem"
assert {"README.md", "source.py", "source-alias.py", "notes.txt"} <= set(included)
for path in (".env", ".env.production", "node_modules", "build", ".venv"):
    assert any(name == path or name.startswith(path + "/") for name in excluded), (path, excluded)
for path, reason in (("outside-directory", "symlink"), ("outside-file", "symlink"), ("broken-link", "symlink"), ("named-pipe", "special_file"), ("embedded", "nested_repository")):
    assert excluded[path]["reason"] == reason, (path, excluded)
assert not any(name.startswith("embedded/") or name.startswith("outside-directory/") for name in included)
'
	python3 - "${ARCHIVE_FIXTURE}" "${TEST_HOME}/before.json" <<'PY'
import json
from pathlib import Path
import sys
current = sorted(str(path.relative_to(sys.argv[1])) for path in Path(sys.argv[1]).rglob("*"))
assert current == json.loads(Path(sys.argv[2]).read_text()), current
PY
}

@test "archive Git selection honors custom ignores and preserves tracked ignored files" {
	_archive_fixture --git
	_archive "${ARCHIVE_PROJECT}" --dry-run --json
	assert_success
	_assert_archive_json '
assert report["complete"] and report["selection_mode"] == "git"
assert included["source.py"]["reason"] == "git_tracked"
assert included["notes.txt"]["reason"] == "git_untracked"
assert included["ignored-but-tracked.txt"]["reason"] == "git_tracked"
assert excluded["custom-local.txt"]["reason"] == "git_ignored"
assert ".env.production" not in included
assert excluded[".env.production"]["reason"] == "common_filter"
assert ".git" in excluded and excluded[".git"]["reason"] == "git_metadata"
'
}

@test "archive creates a safe Git archive when descriptor paths do not support child traversal" {
	_archive_fixture --git
	local archive_file="${ARCHIVE_FIXTURE}/physical-paths.tar.gz"
	run python3 "${MANTLE_ROOT}/tests/fixtures/archive/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/archive.py" "${ARCHIVE_PROJECT}" "${archive_file}" fd-paths
	assert_success
	_assert_archive_json '
assert report["complete"] and not report["dry_run"] and report["selection_mode"] == "git"
assert len(report["sha256"]) == 64
assert included["source.py"]["reason"] == "git_tracked"
assert included["notes.txt"]["reason"] == "git_untracked"
assert included["ignored-but-tracked.txt"]["reason"] == "git_tracked"
assert excluded["custom-local.txt"]["reason"] == "git_ignored"
assert excluded[".env.production"]["reason"] == "common_filter"
assert excluded[".git"]["reason"] == "git_metadata"
assert excluded["outside-file"]["reason"] == "symlink"
assert excluded["embedded"]["reason"] == "nested_repository"
'
	python3 - "${archive_file}" "${output}" <<'PY'
import json
import sys
import tarfile
report = json.loads(sys.argv[2])
with tarfile.open(sys.argv[1], "r:gz") as stream:
    members = stream.getmembers()
    assert all(member.isfile() or member.isdir() for member in members)
    files = {member.name for member in members if member.isfile()}
    assert files == {"project/" + entry["path"] for entry in report["included"]}
    assert stream.extractfile("project/source.py").read() == b"print(\"fixture\")\n"
PY
}

@test "archive exact include overrides filters without broadening to sibling files" {
	_archive_fixture --git
	printf "still excluded\n" >"${ARCHIVE_PROJECT}/build/sibling.txt"
	_archive "${ARCHIVE_PROJECT}" --dry-run --json --include build/generated.txt --include custom-local.txt
	assert_success
	_assert_archive_json '
assert included["build/generated.txt"]["reason"] == "explicit_include"
assert included["custom-local.txt"]["reason"] == "explicit_include"
assert "build/sibling.txt" not in included
assert ".env" not in included and "outside-file" not in included
'
	_archive "${ARCHIVE_PROJECT}" --dry-run --json --include outside-file --include embedded/nested.txt
	assert_status 1
	_assert_archive_json '
assert not report["complete"]
assert "outside-file" not in included and "embedded/nested.txt" not in included
assert excluded["outside-file"]["reason"] == "symlink"
assert excluded["embedded"]["reason"] == "nested_repository"
'
	_archive "${ARCHIVE_PROJECT}" --dry-run --json --include build
	assert_failure
}

@test "archive reports control-character filenames safely in JSON and human output" {
	_archive_fixture
	_archive "${ARCHIVE_PROJECT}" --dry-run --json
	assert_success
	_assert_archive_json 'assert "line\nbreak\x1b[31m.txt" in included'
	[[ "${output}" != *$'\033'* ]]
	_archive "${ARCHIVE_PROJECT}" --dry-run
	assert_success
	[[ "${output}" != *$'\033'* ]]
	assert_output_contains 'line\nbreak\u001b[31m.txt'
}

@test "archive creates a portable archive with regular entries and matching contents" {
	_archive_fixture
	local archive_file="${ARCHIVE_FIXTURE}/result.tar.gz"
	_archive "${ARCHIVE_PROJECT}" --output "${archive_file}" --json
	assert_success
	_assert_archive_json '
assert report["complete"] and not report["dry_run"]
assert len(report["sha256"]) == 64
'
	python3 - "${archive_file}" "${ARCHIVE_PROJECT}" "${output}" <<'PY'
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import tarfile

archive = Path(sys.argv[1])
project = Path(sys.argv[2])
report = json.loads(sys.argv[3])
assert hashlib.sha256(archive.read_bytes()).hexdigest() == report["sha256"]
with tarfile.open(archive, "r:gz") as stream:
    files = {}
    for member in stream.getmembers():
        parts = PurePosixPath(member.name).parts
        assert parts and parts[0] == "project" and ".." not in parts, member.name
        assert not PurePosixPath(member.name).is_absolute(), member.name
        assert member.isfile() or member.isdir(), member
        if member.isfile():
            relative = "/".join(parts[1:])
            files[relative] = stream.extractfile(member).read()
            assert files[relative] == (project / relative).read_bytes(), relative
    assert set(files) == {entry["path"] for entry in report["included"]}, files
    assert files["source.py"] == files["source-alias.py"]
PY
}

@test "archive reproducible mode yields identical bytes with fixed metadata and executable modes" {
	_archive_fixture
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_FIXTURE}/first.tar.gz" --reproducible --json
	assert_success
	python3 - "${ARCHIVE_PROJECT}" <<'PY'
import os
from pathlib import Path
import sys
for name in ("README.md", "script.sh", "source.py"):
    os.utime(Path(sys.argv[1]) / name, (1777777777, 1777777777))
PY
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_FIXTURE}/second.tar.gz" --reproducible --json
	assert_success
	python3 - "${ARCHIVE_FIXTURE}/first.tar.gz" "${ARCHIVE_FIXTURE}/second.tar.gz" <<'PY'
from pathlib import Path
import sys
import tarfile
assert Path(sys.argv[1]).read_bytes() == Path(sys.argv[2]).read_bytes()
with tarfile.open(sys.argv[1], "r:gz") as stream:
    for member in stream.getmembers():
        assert member.uid == member.gid == member.mtime == 0, member
        assert member.uname == member.gname == "", member
        assert member.mode in (0o644, 0o755), member
    assert stream.getmember("project/script.sh").mode == 0o755
    assert stream.getmember("project/README.md").mode == 0o644
PY
}

@test "archive never overwrites an existing output or a hardlink alias" {
	_archive_fixture
	printf "preserve this\n" >"${ARCHIVE_FIXTURE}/existing.tar.gz"
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_FIXTURE}/existing.tar.gz" --json
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["sha256"] is None'
	[[ "$(cat "${ARCHIVE_FIXTURE}/existing.tar.gz")" == "preserve this" ]]
	ln "${ARCHIVE_PROJECT}/source.py" "${ARCHIVE_FIXTURE}/alias.tar.gz"
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_FIXTURE}/alias.tar.gz" --json
	assert_status 1
	[[ "$(cat "${ARCHIVE_FIXTURE}/alias.tar.gz")" == 'print("fixture")' ]]
}

@test "archive dry-run previews the requested output and all existing hardlink aliases" {
	_archive_fixture
	local archive_file="${ARCHIVE_PROJECT}/preview.tar.gz"
	_archive "${ARCHIVE_PROJECT}" --dry-run --output "${archive_file}" --json
	assert_success
	_assert_archive_json 'assert report["dry_run"] and report["output"].endswith("/preview.tar.gz") and report["sha256"] is None'
	assert_file_not_exists "${archive_file}"
	printf "existing archive\n" >"${archive_file}"
	ln "${archive_file}" "${ARCHIVE_PROJECT}/preview-alias.tar.gz"
	_archive "${ARCHIVE_PROJECT}" --dry-run --output "${archive_file}" --json
	assert_status 1
	_assert_archive_json '
assert not report["complete"]
assert "preview.tar.gz" not in included and "preview-alias.tar.gz" not in included
assert excluded["preview.tar.gz"]["reason"] == excluded["preview-alias.tar.gz"]["reason"] == "output"
'
	[[ "$(cat "${archive_file}")" == "existing archive" ]]
}

@test "archive refuses symlink outputs ancestors and components hidden by dot dot" {
	_archive_fixture
	ln -s "${ARCHIVE_FIXTURE}/outside/secret.txt" "${ARCHIVE_FIXTURE}/output.tar.gz"
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_FIXTURE}/output.tar.gz" --json
	assert_status 1
	ln -s "${ARCHIVE_FIXTURE}/outside" "${ARCHIVE_FIXTURE}/linked-parent"
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_FIXTURE}/linked-parent/result.tar.gz" --json
	assert_status 1
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_FIXTURE}/linked-parent/../hidden.tar.gz" --json
	assert_status 1
	assert_file_not_exists "${ARCHIVE_FIXTURE}/hidden.tar.gz"
	assert_file_not_exists "${ARCHIVE_FIXTURE}/outside/result.tar.gz"
}

@test "archive output inside the project excludes itself and temporary publication files" {
	_archive_fixture
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_PROJECT}/bundle.tar.gz" --json
	assert_success
	python3 - "${ARCHIVE_PROJECT}/bundle.tar.gz" <<'PY'
import sys
import tarfile
with tarfile.open(sys.argv[1], "r:gz") as stream:
    assert not any(member.name.endswith("bundle.tar.gz") for member in stream.getmembers())
    assert not any(".mantle" in member.name for member in stream.getmembers())
PY
}

@test "archive permits a nested output directory while preserving its selected sibling files" {
	_archive_fixture
	mkdir "${ARCHIVE_PROJECT}/out"
	printf "selected sibling\n" >"${ARCHIVE_PROJECT}/out/keep.txt"
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_PROJECT}/out/result.tar.gz" --json
	assert_success
	_assert_archive_json 'assert "out/keep.txt" in included and "out/result.tar.gz" not in included'
	python3 - "${ARCHIVE_PROJECT}/out/result.tar.gz" <<'PY'
import sys
import tarfile
with tarfile.open(sys.argv[1], "r:gz") as stream:
    assert stream.extractfile("project/out/keep.txt").read() == b"selected sibling\n"
    assert "project/out/result.tar.gz" not in stream.getnames()
PY
}

@test "archive rejects symlink source paths and paths crossing a symlink before dot dot" {
	_archive_fixture
	ln -s "${ARCHIVE_PROJECT}" "${ARCHIVE_FIXTURE}/linked-project"
	_archive "${ARCHIVE_FIXTURE}/linked-project" --dry-run --json
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"]'
	_archive "${ARCHIVE_FIXTURE}/linked-project/../project" --dry-run --json
	assert_status 1
}

@test "archive rejects archive member names containing a backslash traversal escape" {
	_archive_fixture
	printf "unsafe archive name\n" >"${ARCHIVE_PROJECT}/..\escape.txt"
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_FIXTURE}/unsafe.tar.gz" --json
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"]'
	assert_file_not_exists "${ARCHIVE_FIXTURE}/unsafe.tar.gz"
}

@test "archive explains missing Python while other mantle commands remain usable" {
	_archive_minimal_path
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" archive "${TEST_HOME}" --dry-run
	assert_status 69
	assert_output_contains "Python"
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" version
	assert_success
}

@test "archive filesystem fallback works without Git but Git roots require it" {
	_archive_fixture
	_archive_minimal_path python3
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" archive "${ARCHIVE_PROJECT}" --dry-run --json
	assert_success
	_assert_archive_json 'assert report["selection_mode"] == "filesystem" and report["complete"]'
	git -C "${ARCHIVE_PROJECT}" init --quiet
	run env -i HOME="${TEST_HOME}" MANTLE_ROOT="${MANTLE_ROOT}" PATH="${STUB_DIR}" \
		"${MANTLE_BIN}" archive "${ARCHIVE_PROJECT}" --dry-run --json
	assert_status 69
}

@test "archive Git errors fail closed instead of silently switching to filesystem selection" {
	_archive_fixture --git
	cat >"${STUB_DIR}/git" <<'SH'
#!/bin/sh
printf "fixture Git failure\n" >&2
exit 42
SH
	chmod 0755 "${STUB_DIR}/git"
	_archive "${ARCHIVE_PROJECT}" --output "${ARCHIVE_FIXTURE}/failed.tar.gz" --json
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"]'
	assert_file_not_exists "${ARCHIVE_FIXTURE}/failed.tar.gz"
}

@test "archive refuses unsafe Git ignore files and BOM config includes before invoking Git" {
	_archive_fixture --git
	create_recording_stub git 99
	rm "${ARCHIVE_PROJECT}/.gitignore"
	python3 - "${ARCHIVE_PROJECT}/.gitignore" <<'PY'
import os
import sys
os.mkfifo(sys.argv[1])
PY
	_archive "${ARCHIVE_PROJECT}" --dry-run --json
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"]'
	assert_file_not_exists "${STUB_DIR}/git.calls"
	rm "${ARCHIVE_PROJECT}/.gitignore"
	ln -s "${ARCHIVE_FIXTURE}/outside/secret.txt" "${ARCHIVE_PROJECT}/.gitignore"
	_archive "${ARCHIVE_PROJECT}" --dry-run --json
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"]'
	assert_file_not_exists "${STUB_DIR}/git.calls"
	rm "${ARCHIVE_PROJECT}/.gitignore"
	printf "custom-local.txt\n" >"${ARCHIVE_PROJECT}/.gitignore"
	python3 - "${ARCHIVE_PROJECT}/.git/config" "${ARCHIVE_FIXTURE}/external.cfg" <<'PY'
from pathlib import Path
import sys
configuration = Path(sys.argv[1])
external = Path(sys.argv[2])
external.write_text("[core]\n bare = true\n")
configuration.write_bytes(b"\xef\xbb\xbf[include]\n path = " + str(external).encode() + b"\n" + configuration.read_bytes())
PY
	_archive "${ARCHIVE_PROJECT}" --dry-run --json
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"]'
	assert_file_not_exists "${STUB_DIR}/git.calls"
}

@test "archive excludes a different filesystem without requiring a real mount" {
	_archive_fixture
	mkdir "${ARCHIVE_PROJECT}/other-device"
	printf "outside scan device\n" >"${ARCHIVE_PROJECT}/other-device/keep.txt"
	run python3 "${MANTLE_ROOT}/tests/fixtures/archive/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/archive.py" "${ARCHIVE_PROJECT}" "${ARCHIVE_FIXTURE}/unused.tar.gz" device
	assert_success
	_assert_archive_json '
assert report["complete"] and "other-device/keep.txt" not in included
assert excluded["other-device"]["reason"] == "filesystem_boundary"
'
	assert_file_not_exists "${ARCHIVE_FIXTURE}/unused.tar.gz"
}

@test "archive read failures abort publication and clean owned temporary files under root too" {
	_archive_fixture
	local archive_file="${ARCHIVE_FIXTURE}/read-failure.tar.gz"
	run python3 "${MANTLE_ROOT}/tests/fixtures/archive/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/archive.py" "${ARCHIVE_PROJECT}" "${archive_file}" read
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"] and report["sha256"] is None'
	assert_file_not_exists "${archive_file}"
	[[ "$(find "${ARCHIVE_FIXTURE}" -maxdepth 1 -type f -name '*.tmp' -print)" == "" ]]
}

@test "archive output write failures leave no published output or temporary archive" {
	_archive_fixture
	local archive_file="${ARCHIVE_FIXTURE}/write-failure.tar.gz"
	run python3 "${MANTLE_ROOT}/tests/fixtures/archive/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/archive.py" "${ARCHIVE_PROJECT}" "${archive_file}" write
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"] and report["sha256"] is None'
	assert_file_not_exists "${archive_file}"
	[[ "$(find "${ARCHIVE_FIXTURE}" -maxdepth 1 -type f -name '*.tmp' -print)" == "" ]]
}

@test "archive refuses inputs changed after selection and leaves no output" {
	_archive_fixture
	local archive_file="${ARCHIVE_FIXTURE}/changed.tar.gz"
	run python3 "${MANTLE_ROOT}/tests/fixtures/archive/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/archive.py" "${ARCHIVE_PROJECT}" "${archive_file}" changed
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"] and report["sha256"] is None'
	assert_file_not_exists "${archive_file}"
}

@test "archive atomic publication preserves a competing output created after selection" {
	_archive_fixture
	local archive_file="${ARCHIVE_FIXTURE}/race.tar.gz"
	run python3 "${MANTLE_ROOT}/tests/fixtures/archive/probe-faults.py" \
		"${MANTLE_ROOT}/libexec/mantle/archive.py" "${ARCHIVE_PROJECT}" "${archive_file}" publish
	assert_status 1
	_assert_archive_json 'assert not report["complete"] and report["warnings"] and report["sha256"] is None'
	[[ "$(cat "${archive_file}")" == "concurrent output must survive" ]]
	[[ "$(find "${ARCHIVE_FIXTURE}" -maxdepth 1 -type f -name '*.tmp' -print)" == "" ]]
}
