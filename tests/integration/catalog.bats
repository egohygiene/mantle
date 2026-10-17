#!/usr/bin/env bats
# The catalog describes existing public commands without executing them.

setup() {
	load '../test_helper/common'
	load '../test_helper/assertions'
	load '../test_helper/profiles'
	setup_isolated_home
	setup_stub_dir
	PROFILE_ROOT="${MANTLE_ROOT}"
}

teardown() {
	teardown_stub_dir
	teardown_isolated_home
}

# @description Apply one trusted mutation to a copied catalog.
# @arg $1 string Python mutation with the document variable available.
_catalog_mutate() {
	python3 - "${PROFILE_ROOT}/config/commands.json" "$1" <<'PY'
import json
from pathlib import Path
import sys
path = Path(sys.argv[1])
document = json.loads(path.read_text())
exec(sys.argv[2])
path.write_text(json.dumps(document) + "\n")
PY
}

@test "catalog lists exactly the installed flat executables and public dispatcher commands" {
	profile_test_require_python
	profile_test_cli catalog list --json
	assert_success
	profile_test_json '
commands = report["commands"]
actual = {command["id"]: command["path"] for command in commands}
expected = {path.name: path.relative_to(root).as_posix() for path in (root / "bin").iterdir() if path.is_file() and os.access(path, os.X_OK)}
expected.update({"mantle " + path.stem: path.relative_to(root).as_posix() for path in (root / "libexec/mantle/commands").glob("*.sh") if path.is_file() and os.access(path, os.X_OK)})
assert actual == expected, (actual, expected)
assert len(actual) == len(commands)
assert [command["id"] for command in commands] == sorted(actual)
'
	local first="${output}"
	profile_test_cli catalog list --json
	assert_success
	[[ "${output}" == "${first}" ]]
}

@test "catalog validates its inventory and retains honest unknown legacy requirements" {
	profile_test_require_python
	profile_test_cli catalog list --json
	assert_success
	profile_test_json '
legacy = [command for command in report["commands"] if command["review_status"] == "unreviewed"]
assert legacy, report
for command in legacy:
    assert command["network"] is None and command["privilege"] is None, command
    assert command["platforms"] is None and command["dependencies"] is None, command
'
	profile_test_cli catalog validate --json
	assert_success
	profile_test_json 'assert report["valid"] and report["commands"] > 0'
}

@test "catalog profile filtering includes inherited recommendations without restricting invocation" {
	profile_test_require_python
	profile_test_cli catalog list --json
	assert_success
	printf "%s\n" "${output}" >"${TEST_HOME}/all-commands.json"
	profile_test_cli profiles show ci --json
	assert_success
	printf "%s\n" "${output}" >"${TEST_HOME}/ci-profile.json"
	profile_test_cli catalog list --profile ci --json
	assert_success
	python3 - "${output}" "${TEST_HOME}/all-commands.json" "${TEST_HOME}/ci-profile.json" <<'PY'
import json
from pathlib import Path
import sys
actual = json.loads(sys.argv[1])
all_commands = json.loads(Path(sys.argv[2]).read_text())["commands"]
inherited = set(json.loads(Path(sys.argv[3]).read_text())["profile"]["resolved_profiles"])
expected = [command for command in all_commands if inherited.intersection(command["profiles"])]
assert actual["profile"] == "ci" and actual["commands"] == expected
PY
	profile_test_cli version
	assert_success
}

@test "catalog validation detects newly added and removed public commands" {
	profile_test_require_python
	profile_test_copy_tree
	printf '#!/bin/sh\nexit 99\n' >"${PROFILE_ROOT}/bin/uncataloged-fixture"
	chmod 0755 "${PROFILE_ROOT}/bin/uncataloged-fixture"
	profile_test_cli catalog validate
	assert_status 78
	assert_output_contains "uncataloged-fixture"
	rm "${PROFILE_ROOT}/bin/uncataloged-fixture"
	rm "${PROFILE_ROOT}/bin/weather"
	profile_test_cli catalog validate
	assert_status 78
	assert_output_not_contains "Traceback"
}

@test "catalog rejects duplicate identities and unsafe stale or nonexecutable paths" {
	profile_test_require_python
	profile_test_copy_tree
	cp "${PROFILE_ROOT}/config/commands.json" "${TEST_HOME}/catalog-original.json"
	local mutation
	for mutation in \
		'document["commands"].append(dict(document["commands"][0]))' \
		'document["commands"][0]["path"] = "../outside"' \
		'document["commands"][0]["path"] = "bin/missing-fixture"' \
		'document["commands"][0]["path"] = document["commands"][1]["path"]'; do
		cp "${TEST_HOME}/catalog-original.json" "${PROFILE_ROOT}/config/commands.json"
		_catalog_mutate "${mutation}"
		profile_test_cli catalog validate --json
		assert_status 78
		assert_output_not_contains "Traceback"
	done
	cp "${TEST_HOME}/catalog-original.json" "${PROFILE_ROOT}/config/commands.json"
	chmod 0644 "${PROFILE_ROOT}/bin/weather"
	profile_test_cli catalog validate
	assert_status 78
}

@test "catalog rejects invalid profile platform dependency and safety metadata types" {
	profile_test_require_python
	profile_test_copy_tree
	cp "${PROFILE_ROOT}/config/commands.json" "${TEST_HOME}/catalog-original.json"
	local mutation
	for mutation in \
		'document["commands"][0]["profiles"] = ["missing-profile"]' \
		'document["commands"][0]["platforms"] = ["amiga"]' \
		'document["commands"][0]["dependencies"] = ["tool;execute"]' \
		'document["commands"][0]["network"] = "false"' \
		'document["commands"][0]["category"] = []' \
		'document["schema_version"] = True'; do
		cp "${TEST_HOME}/catalog-original.json" "${PROFILE_ROOT}/config/commands.json"
		_catalog_mutate "${mutation}"
		profile_test_cli catalog validate --json
		assert_status 78
		assert_output_not_contains "Traceback"
	done
}

@test "catalog rejects duplicate JSON keys and unknown metadata fields" {
	profile_test_require_python
	profile_test_copy_tree
	_catalog_mutate 'document["commands"][0]["invented_field"] = "unsupported"'
	profile_test_cli catalog validate
	assert_status 78
	printf '{"schema_version":1,"schema_version":1,"commands":[]}\n' >"${PROFILE_ROOT}/config/commands.json"
	profile_test_cli catalog validate
	assert_status 78
	assert_output_contains "duplicate"
}

@test "catalog introspection never executes cataloged utilities" {
	profile_test_require_python
	profile_test_copy_tree
	cat >"${PROFILE_ROOT}/bin/weather" <<'SH'
#!/bin/sh
printf "unexpected catalog execution\n" >"${HOME}/utility-executed"
exit 99
SH
	chmod 0755 "${PROFILE_ROOT}/bin/weather"
	profile_test_cli catalog validate --json
	assert_success
	profile_test_cli catalog list --json
	assert_success
	assert_file_not_exists "${TEST_HOME}/utility-executed"
}

@test "catalog and profile help work without Python and introspection reports the dependency" {
	local tool
	for tool in bash basename dirname readlink env; do
		ln -s "$(command -v "${tool}")" "${STUB_DIR}/${tool}"
	done
	PROFILE_TEST_PATH="${STUB_DIR}"
	profile_test_cli help profiles
	assert_success
	profile_test_cli help catalog
	assert_success
	profile_test_cli profiles list --json
	assert_status 69
	profile_test_cli catalog list --json
	assert_status 69
}
